# ADR-0101: Disable ACPI on OptiPlex 3000 Proxmox Node to Fix Boot Loop

**Date:** 2026-07-23

**Status:** Superseded by ADR-0102 — root cause was power delivery, not ACPI

### Context

One of the three Proxmox VE cluster nodes (Dell OptiPlex 3000 Micro, Intel i5-12500T, 6C/12T) will not boot reliably with ACPI enabled. With a default kernel command line, the node crashes and resets during early boot (after GRUB loads the kernel and begins mounting the root filesystem via LVM), cycling back to the GRUB menu in a tight loop (power light stays on, no full power cycle between attempts). The front-panel diagnostic LEDs flash a pattern during the failed attempts that doesn't map to any documented Dell POST error code for this chassis, which is consistent with the reset happening after POST, in the OS boot path, rather than being a genuine hardware fault.

This behavior was previously discovered and worked around by adding `acpi=off` to the kernel boot parameters (`GRUB_CMDLINE_LINUX_DEFAULT`). At some point that workaround was removed (or the node was reinstalled without it) as part of investigating why the node only exposed 1 CPU core instead of 12 threads. Re-testing without `acpi=off` reproduced the crash/reset loop, confirming the setting is required, not leftover cruft.

**Root cause of the CPU limitation:** On modern x86 hardware, the kernel discovers additional cores and local APICs exclusively through the ACPI MADT (Multiple APIC Description Table) — there is no legacy fallback multiprocessor table on hardware this recent. Disabling ACPI entirely (`acpi=off`) therefore blinds the kernel to every core beyond the boot CPU as a side effect, forcing single-core operation. This is expected kernel behavior, not a bug in this setup.

### Decision

Keep `acpi=off` in `GRUB_CMDLINE_LINUX_DEFAULT` on this node, accepting single-core (1 of 12 threads) operation in exchange for a stable boot.

Do not attempt to remove `acpi=off` on this node again without first trying a narrower workaround (see Alternatives) in a low-risk way — e.g. testing at the GRUB boot-menu edit screen before writing changes to disk.

### Consequences

**Positive:**
- Node boots reliably and stays up.

**Negative:**
- Node runs at roughly 1/12th of its CPU capacity, making it unsuitable for meaningful VM/LXC workloads until resolved. It is effectively idle capacity in the cluster today.
- Full ACPI-derived power management, thermal management, and CPU frequency scaling are unavailable while `acpi=off` is set.

**Recovery notes for future reboots:**
- If this node ever needs to boot without `acpi=off` for testing, do it as a one-time edit at the GRUB menu (highlight the entry, press `e`, append `acpi=off` removed/added to the `linux` line, boot with F10/Ctrl+X) rather than editing `/etc/default/grub` directly — that way a failed boot doesn't require console recovery to undo.
- A backup of the working config is kept at `/etc/default/grub.bak-acpi` on the node itself.

### Alternatives Considered

**`noapic` instead of `acpi=off`:**
- `noapic` disables IO-APIC interrupt routing only and leaves the Local APIC (and therefore multi-core boot) intact. If the underlying issue is IO-APIC-related (a common category of ACPI/BIOS bug), this could restore full core count while still avoiding the crash.
- Not yet tested — deferred because reproducing boot failures on this hardware requires physical console access and each failed attempt costs real time. Worth trying in a future session with the console already in hand.

**BIOS/firmware update:**
- Dell has shipped BIOS updates that fix ACPI table bugs on other OptiPlex Micro generations. Not checked yet for this specific unit.
- Deferred for the same reason as above — worth checking before spending more time on kernel-parameter workarounds.

**Live with 1 core permanently:**
- This is the current de facto state. Acceptable short-term since this node currently has zero VMs/LXCs assigned to it, but wastes hardware that could otherwise host real workloads.

---
