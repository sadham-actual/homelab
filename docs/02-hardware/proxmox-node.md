# Proxmox Cluster Hardware

## Cluster Overview

The Proxmox VE cluster is named `homelab` and currently has three nodes, all Dell OptiPlex Micro form-factor desktops. All three joined the cluster and are quorate (2-of-3 minimum for quorum).

| Node | Model | CPU | RAM | Storage | BIOS | Role |
|------|-------|-----|-----|---------|------|------|
| `pve-01` | Dell OptiPlex 3080 Micro | i5-10500T (6C/12T) | 16GB DDR4-2400 | 256GB NVMe | 2.35.0 | Primary — hosts current VMs/LXCs |
| `pve-02` | Dell OptiPlex 3000 Micro | i5-12500T (6C/12T) | 32GB DDR4-3200 | 512GB NVMe | 1.39.1 | Idle — on a dedicated 100W adapter; see power delivery note below |
| `pve-03` | Dell OptiPlex 3080 Micro | i5-10500T (6C/12T) | 16GB DDR4-2666 | 256GB NVMe | 2.34.0 | Idle |

All three nodes: single Gigabit Ethernet NIC, connected to `vmbr0` on the flat `192.168.1.0/24` network (no VLANs yet — see [Networking: Current Setup](../06-networking/current-setup.md)).

**Note on RAM:** Earlier planning docs assumed 40GB on a single node; actual installed RAM (confirmed via `dmidecode`) is 16GB on each 3080 Micro and 32GB on the 3000 Micro. `pve-03` runs mismatched DIMMs (one DDR4-3200, one DDR4-2666) and therefore clocks both at the slower speed — use matched pairs in any future node. The 3080 Micro board supports **64GB max across 2 slots**, so a replacement node need not lose capacity relative to the 3000 Micro.

## BIOS

**Software versions (2026-09-04):** all three nodes run **pve-manager 9.2.11 / proxmox-ve 9.2.0** on kernel **7.0.14-15-pve**, with 0 pending updates. See [Upgrades and Kernel Pinning](../04-proxmox/upgrades-and-kernels.md) for the procedure and the pinning traps.

**Keep BIOS versions current and matched.** `pve-01` ran on its factory 1.1.0 (2020) until 2026-09-03, which caused a persistently over-driven cooling fan — audible at idle while running *cooler* than its identically-specced twin. Flashing to 2.35.0 fixed it. Full writeup: [Diagnosing Hardware by Comparison](../10-lessons-learned/diagnosing-hardware-by-comparison.md). `pve-03` is still on 2.34.0 and behaving; bring it to 2.35.0 during a maintenance window.

**Before any BIOS flash on a Proxmox host**, dump the current settings — a large version jump usually resets them to defaults:

```bash
# Dell exposes BIOS attributes read-only in sysfs
d=/sys/class/firmware-attributes/dell-wmi-sysman/attributes
for a in $(ls $d); do
  [ -f "$d/$a/current_value" ] && echo "$a = $(cat $d/$a/current_value)"
done > bios-baseline.txt
```

The settings that matter afterwards: `Virtualization` and `VtForDirectIo` (lose either and VMs won't start), `AcPwrRcvry` (lose it and the node stays dark after a power cut), `BootList`, `SecureBoot`.

## Known Issue: pve-02 Power Delivery

`pve-02` is currently powered by a dedicated 100W USB-C PD brick rather than the shared power rig used by the other two nodes (one upstream supply feeding 5x 65W USB-C PD trigger boards → USB-C-to-Dell-barrel adapters). The shared rig could not reliably deliver the current spike from bringing all 12 threads online, causing a boot crash-loop; the dedicated 100W brick resolved it. Full writeup: [ADR-0102](../../decisions/0102-pve-node-power-delivery-fix.md) (supersedes the earlier, incorrect ACPI-based diagnosis in [ADR-0101](../../decisions/0101-pve-node-acpi-workaround.md)).

### Recurrence 2026-09-03

`pve-02` was at some point moved back onto the shared 65W rig, and the fault returned exactly as ADR-0102 predicted. Four consecutive boot attempts collapsed — `journalctl --list-boots` recorded four boots that **started and ended in the same second** — on both the newer kernel *and* the known-good fallback, confirming the failure is power, not software. A 100W adapter booted it first try. Cost: 7 additional unsafe shutdowns.

The same root cause also explains the node's ~20/day corosync ring flaps, previously tracked as an unrelated network problem. Brief voltage sags stall CPU and NIC together for a few hundred milliseconds — invisible to every log, indifferent to corosync's realtime priority. See [Diagnosing Hardware by Comparison](../10-lessons-learned/diagnosing-hardware-by-comparison.md).

### Confirmed fixed 2026-09-04

After 11.3 hours on the 100W adapter:

| Metric | Baseline (65W rig) | After |
|---|---|---|
| Corosync ring flaps | ~20/day (~9.6 expected in this window) | **0** |
| TOTEM retransmits | ~290/day | **0** |
| Kernel link-down events | — | **0** |

Corroborated independently from all three nodes — `pve-01` and `pve-03` previously logged 24 and 38 `host: 2 link: 0 is down` events per day respectively, and now log zero. A 5/sec ping monitor recorded 201,547 replies with no timeouts. At the old rate, observing zero flaps in this window has a probability of roughly 1 in 14,000.

Verify the count any time with:

```bash
# each flap logs both peers, so divide by two
journalctl -u corosync --since "<test start>" | grep -c "has no active links"
```

**Attribution — resolved 2026-09-04.** The initial window changed adapter *and* kernel together, so it did not isolate the cause on its own. Subsequent evidence does:

- **Unstable across kernels on the 65W supply** — months of unsafe shutdowns and ~20 flaps/day on 6.14.11-8, and boot brownouts on *both* 6.17.13-21 and the known-good 6.14.11-8 fallback.
- **Stable across kernels on the 100W supply** — 6.17.13-21 for 13h with zero flaps, then 7.0.14-15 with the same clean result.

The kernel was varied on both sides of the change and made no difference; the adapter did. Combined with the operator's own account that this node has only ever misbehaved while on the custom PDU, **the power supply was the cause**. The kernel-mismatch theory is fully retired.

### Shared-rig headroom — follow-up now answered

ADR-0102 left open whether `pve-01`/`pve-03` had adequate headroom on the shared 65W boards. **Measured 2026-09-03 on `pve-03`: yes, with ~14% margin.**

Use the `psys` RAPL domain for *whole-platform* power. `intel-rapl:0` is CPU package only and significantly understates the total:

```bash
# psys = platform-wide; intel-rapl:0 = CPU package only
PSYS=/sys/class/powercap/intel-rapl:1/energy_uj
a=$(cat $PSYS); sleep 10; b=$(cat $PSYS)
echo "scale=2; ($b-$a)/10000000" | bc

# Saturate CPU + RAM + disk together (stress-ng is preinstalled on PVE)
stress-ng --cpu 12 --cpu-method all --vm 2 --vm-bytes 2G --hdd 2 --hdd-bytes 256M --timeout 70s
```

| Measurement (3080 Micro / i5-10500T) | Value |
|---|---|
| Platform idle | 4.8–5.3 W |
| Platform peak, CPU+RAM+disk saturated | **55.97 W** |
| Supply budget | 65 W |
| Headroom | **~9 W (14%)** |

Held 3500 MHz all-core throughout, 74°C, no throttling, no brownout.

**Why the 3000 Micro cannot fit the same budget:**

| | 3080 / i5-10500T | 3000 / i5-12500T |
|---|---|---|
| PL1 sustained | 35 W | 35 W |
| PL2 burst | 68 W | **77 W** |
| **Platform idle** | **5.3 W** | **21.8 W** |

The 12th-gen part idles ~16W higher; adding the same ~50W dynamic load puts it near **72W** against a 65W supply, with a PL2 ceiling 9W above it. This quantitatively confirms ADR-0102's planned resolution — replace the 3000 Micro with a matching 3080 Micro rather than redesigning the power rig.

**Two caveats on that 14% margin:** `psys` is the CPU's own estimate and excludes PD-board conversion losses, so real draw at the barrel is somewhat higher. And **boot transients cannot be reproduced from inside a running OS** — that is the regime that actually kills the 3000 Micro. The 3080s are proven empirically across many clean boots, so this is not a concern for them, but the stress test validates *running* load, not *starting* load.

## Current Workloads

All current VMs/LXCs run on `pve-01`; `pve-02` and `pve-03` have no workloads assigned yet.

| ID | Name | Type | Status | vCPU | RAM | Disk | Notes |
|----|------|------|--------|------|-----|------|-------|
| 101 | docker-1 | VM | running | 4 | 8GB | 64GB | Ubuntu 24.04 Server, general-purpose Docker host, `onboot=1` |
| 103 | actualbudget | LXC | running | 2 | 2GB | 4GB | Debian, unprivileged, deployed via community-scripts.org Proxmox VE script, `onboot=1` |

VM 100 (`openclaw-1`, Ubuntu 24.04 Desktop) was **destroyed 2026-09-03** — an abandoned experiment, reclaiming 40GB. Its user data was archived off the node first.

Local storage on each node: `local` (directory) + `local-lvm` (LVM-thin). Guest disks are all on node-local LVM-thin — no TrueNAS iSCSI/NFS storage is attached for *running* VMs yet.

A cluster-wide NFS storage `pvebackup` **is** now attached, pointing at a TrueNAS dataset, used for nightly guest backups. See [Proxmox Backups](../04-proxmox/backups.md) and [ADR-0006](../../decisions/0006-proxmox-backup-strategy.md).

### VM CPU type and live migration

`docker-1` runs `cpu: host`. While the cluster contains mixed CPU generations (10th-gen and 12th-gen), that setting **blocks live migration** between them. Either standardise the hardware (the planned 3080 swap) or set a common baseline both generations support:

```bash
qm set 101 --cpu x86-64-v3    # both Comet Lake and Alder Lake support AVX2
```

## Planned / Not Yet Done

These items from the original hardware plan have not happened yet:
- TrueNAS iSCSI LUN or NFS mount for **running VM disks** (backup-only NFS storage is now attached; guest disks are still local-lvm)
- k3s deployment (no Kubernetes installed anywhere in the homelab as of this writing)
- OPNsense VM / VLAN network migration (still flat `192.168.1.0/24`)
- Second/third node workload distribution — `pve-02` and `pve-03` are online but idle

## Maintenance Notes

- SSH access: `root@<node-ip>` with key auth (see `~/.ssh/config` aliases `pve-01`/`pve-02`/`pve-03` on the management workstation).
- Before touching `pve-02`'s boot configuration again, read [ADR-0102](../../decisions/0102-pve-node-power-delivery-fix.md) first — the original ACPI diagnosis was wrong and cost real troubleshooting time. If `pve-02` misbehaves in *any* way — boot failures, cluster instability, unexplained resets — **check what is powering it before troubleshooting software.**
- **The kernel pin lives in `GRUB_DEFAULT` in `/etc/default/grub` on all three nodes** (consolidated 2026-09-04; the old user-created `grub.d` drop-ins were retired). The only remaining drop-in is the package-owned `proxmox-ve.cfg` — leave it alone. Always verify a pin change against the generated config, not the file you edited: `grep -oE 'set default="gnulinux-advanced[^"]*' /boot/grub/grub.cfg`. Details in [Upgrades and Kernel Pinning](../04-proxmox/upgrades-and-kernels.md).
- All three nodes keep a pinned kernel so an unattended power-on always lands somewhere known. Do not use `grub-reboot` one-shots on these nodes: `grubenv` sits on LVM, so they are sticky rather than self-clearing. Pick alternate kernels from the GRUB menu at the console instead.
- Menu timeouts are `GRUB_TIMEOUT=5` for normal boots plus `GRUB_RECORDFAIL_TIMEOUT=30`, so a long menu appears only after a *failed* boot — which is when a fallback kernel actually needs selecting.

---

*Last Updated: 2026-09-04*
