# Diagnosing Hardware by Comparison

*Retrospective from a 2026-09-03 troubleshooting session that started with "one node's fan got loud" and ended up touching firmware, power delivery, and the cluster ring.*

Two faults were diagnosed that evening. Neither was visible in any log. Both were found by **comparing a suspect node against a known-good identical one** — and one of them was misdiagnosed twice first.

## The core technique

The cluster has three Dell OptiPlex Micro nodes, two of which (`pve-01`, `pve-03`) are the same model with the same CPU. That redundancy turned out to be worth more than any monitoring tool.

When you have two machines that should behave identically and one doesn't, the *difference* is the diagnosis. Absolute numbers rarely tell you anything — a CPU at 33°C sounds fine in isolation. It is alarming when its twin, doing less work, sits at 35°C.

## Case 1: the loud fan (found in ~10 minutes)

**Symptom:** `pve-01`'s fan became audible at idle for the first time.

**The counterintuitive measurement:**

| | `pve-01` (loud) | `pve-03` (quiet) |
|---|---|---|
| Package power | 4.2 W | 1.0 W |
| Package temp | **33 °C** | 35 °C |

`pve-01` was drawing **four times the power and running cooler**. That combination has exactly one explanation: it was moving far more air than it needed to. The fan was not responding to heat — it was ignoring it.

Nothing thermal was wrong. CPU 33°C, NVMe 26°C, load 0.06.

**Root cause:** `pve-01` was still on its factory **BIOS 1.1.0 (2020-05-31)** — the launch-day firmware, never updated. `pve-03`, identical hardware, was on 2.34.0 (2025-12-01) with five years of thermal-table fixes.

**Fix:** flashed to 2.35.0. Result:

| | Before (BIOS 1.1.0) | After (BIOS 2.35.0) |
|---|---|---|
| Package power | 4.2 W | 4.36 W |
| Package temp | 33 °C | **45 °C** |

**Same power, +12 °C, and the room went quiet.** A *higher* temperature was the success criterion — it meant the fan had stopped over-cooling and let the CPU settle where a 35W part should sit.

### What made this findable

- `sensors` returned nothing (lm-sensors not installed) and `dell_smm_hwmon` will not bind on OptiPlex desktops, so **fan RPM was unreadable from the OS**. The power-to-temperature *ratio* was the only usable signal.
- An EC power-drain (unplug, hold power button 30s) changed nothing, which ruled out transient controller state before any firmware risk was taken.
- Dell's BIOS release notes are almost entirely CVE lists and never mention fan or thermal behaviour. **The changelog could not have confirmed this** — only the A/B against identical hardware could.

### Useful commands

```bash
# Package power over 10s (no extra tooling needed)
a=$(cat /sys/class/powercap/intel-rapl:0/energy_uj); sleep 10
b=$(cat /sys/class/powercap/intel-rapl:0/energy_uj)
echo "scale=2; ($b-$a)/10000000" | bc

# Package temperature — note the zone index is NOT stable across reboots,
# so match on type rather than hardcoding thermal_zone1
for z in /sys/class/thermal/thermal_zone*; do
  [ "$(cat $z/type)" = "x86_pkg_temp" ] && echo "$(($(cat $z/temp)/1000))C"
done

# Dell exposes BIOS settings read-only in sysfs — dump all of them before
# any flash, since a large version jump usually resets them to defaults
d=/sys/class/firmware-attributes/dell-wmi-sysman/attributes
for a in $(ls $d); do
  [ -f "$d/$a/current_value" ] && echo "$a = $(cat $d/$a/current_value)"
done
```

The settings that must survive a Proxmox host's BIOS flash: `Virtualization`, `VtForDirectIo` (lose either and VMs will not start), `AcPwrRcvry` (lose it and the node stays dark after a power cut), `BootList`, `SecureBoot`.

## Case 2: the ring flapping (misdiagnosed twice)

**Symptom:** `pve-02` dropped off the corosync ring ~20×/day, at irregular intervals, recovering instantly. Peers saw it drop; it saw both peers drop.

**The one useful early clue:** it lost **both peers in the same second** and recovered immediately. Two independent peers cannot fail simultaneously and recover together — so the fault had to be local to `pve-02` or its network path.

### What was ruled out, and how

Each of these was a plausible theory killed by comparison against the two stable nodes:

| Hypothesis | Killed by |
|---|---|
| Physical link drops | Only 2 `Link is Down` events, both at boot; 0 in 24h |
| Bad cable / switch port | `ethtool -S` and `ip -s -s link`: **zero** RX errors, CRC, carrier, collisions |
| ASPM (PCIe power saving) | `r8169` logs `can't disable ASPM` — but **all three nodes are identical in this** |
| Deep C-states | The stable node's deepest state has *higher* exit latency (1034 µs vs 680 µs) |
| CPU starvation | `corosync` runs `SCHED_RR` priority **99** on every node |
| SMIs (firmware stealing CPU) | MSR 0x34: the flapping node had the **fewest** — 1,880 vs 161,447 on a stable node |
| Local contention | Journal windows around flap timestamps were completely empty |

Two of these looked like smoking guns and were not. The `can't disable ASPM` boot message is exactly the kind of alarming log line that invites confirmation bias — until you check the other nodes and find it everywhere.

### The wrong answer that looked right

The surviving theory was a **kernel/platform mismatch**: the flapping node was the only 12th-gen (hybrid P+E core) machine, and it was running the *oldest* kernel in the cluster on the *newest* silicon. Plausible, specific, and testable.

It was wrong. Booting the newer kernel browned the machine out — and so did booting the **known-good fallback kernel**. Identical failure on both. The kernel was never the variable.

### The actual root cause

The node was powered from a shared DIY power rig using **65W USB-C PD trigger boards**. Its 12th-gen CPU has a PL2 burst limit of **77W** — the CPU alone can exceed the entire supply. See [ADR-0102](../../decisions/0102-pve-node-power-delivery-fix.md), which had already identified this in July; the node had since been moved back onto the shared rig, and the fault returned exactly as that ADR predicted it would.

Brief voltage sags stall the CPU and NIC *together* for a few hundred milliseconds. That produces precisely the observed signature: no log entry anywhere, indifferent to `corosync`'s realtime priority, both peers lost in the same instant, instant recovery.

**Historical confirmation** came from the boot journal:

```bash
journalctl --list-boots
```

99 boots recorded, **87 of them on just two days** — one cluster of 47, another of 40. The second cluster was spaced at *exactly 21-second intervals*: rail collapses → `AcPwrRcvry=On` powers the machine back up → it dies at the same point in boot → repeat, for an hour.

That same night also explains a previously unrelated mystery: the node's `grub.cfg` had "frozen" on that date, leaving it booting a known-bad kernel unattended for five weeks. An `update-grub` interrupted by a collapsing rail leaves exactly that.

### Confirming the fix

A fix for an intermittent fault is a claim until it's measured against a known rate. The pre-fix baseline was gathered first, deliberately:

```bash
# Baseline: ~20 flaps/day (49 peer-loss pairs over 2.4 days)
journalctl -u corosync --since "<start>" --until "<end>" | grep -c "has no active links"
```

After 11.3 hours on a 100W adapter: **0 flaps, 0 retransmits, 0 link-down events**, confirmed independently from all three nodes. At the old rate ~9.6 flaps were expected; observing zero has a probability around 1 in 14,000 if nothing had changed.

That last number is the point. "It seems better" is not a result for a fault that only fires ~20 times a day — without a baseline and an expected count, a quiet evening proves nothing. Capture the rate *before* changing anything.

One honest limitation at the time: the adapter and the kernel were changed together, so strictly that window showed "adapter and/or kernel."

**Resolved the next day, by accident of unrelated work.** Routine package upgrades moved the node onto a *third* kernel (7.0.14-15), and it stayed clean. So the picture became:

| | 65W supply | 100W supply |
|---|---|---|
| 6.14.11-8 | unstable (months of unsafe shutdowns, ~20 flaps/day) + boot brownout | — |
| 6.17.13-21 | boot brownout | stable, 0 flaps in 13h |
| 7.0.14-15 | — | stable |

The kernel was varied on both sides and changed nothing; the supply was varied and changed everything. That retires the confound without needing the deliberate one-variable experiment.

The lesson survives anyway: **the clean experiment would have changed one variable at a time**, and it was luck rather than design that resolved this one. Had the upgrade not happened, the ambiguity would still be sitting there.

## Lessons

**1. Identical hardware is a diagnostic instrument.** Every correct conclusion here came from an A/B against a twin. Every wrong one came from reasoning about a single machine in isolation. This is a real argument for hardware uniformity in a small cluster that has nothing to do with aesthetics.

**2. "Nothing in the logs" is itself evidence.** It does not mean nothing happened — it narrows the fault to layers the OS cannot see: firmware, power, and hardware. Time spent grepping logs after that point is wasted.

**3. Rule things out with measurements, not plausibility.** The ASPM warning *looked* like the answer. Checking the other two nodes took thirty seconds and killed it. Do that before building a theory on top.

**4. A fix that makes a number worse can be the right fix.** The BIOS flash *raised* idle temperature by 12°C. That was the success signal.

**5. Beware the elegant theory.** "Newest silicon on the oldest kernel" was a genuinely good hypothesis. It was also wrong, and only a test that could disprove it — booting the fallback kernel — revealed that. Design the test to kill the theory, not to confirm it.

**6. Some things are only knowable outside the machine.** No amount of `sysfs` reading would have revealed a 65W power brick. The operator's knowledge of the physical build closed the case.

**7. Baseline the fault rate before you change anything.** An intermittent fault needs a measured before-and-after, or "it seems fine now" is indistinguishable from a quiet evening. Counting flaps per day first is what turned the fix from a hope into a result.

**8. Change one variable at a time — and note it when you don't.** The adapter and kernel were swapped together out of expedience. The conclusion still holds on other evidence, but the experiment was weaker than it needed to be.

---

*Last Updated: 2026-09-04*
