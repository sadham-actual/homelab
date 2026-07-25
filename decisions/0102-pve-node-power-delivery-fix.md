# ADR-0102: Root Cause of pve-02 Boot Loop Was Power Delivery, Not ACPI

**Date:** 2026-07-23

**Status:** Accepted

**Supersedes:** ADR-0101

### Context

ADR-0101 documented `acpi=off` as a required workaround for a Proxmox cluster node (Dell OptiPlex 3000 Micro, Intel i5-12500T, 6C/12T) that crash-looped during boot with ACPI enabled, and accepted the resulting single-core operation as a tradeoff.

While investigating cheaper alternatives to `acpi=off` (see ADR-0101 Alternatives), an unrelated observation reopened the question: the shared power supply feeding this node's power brick ramps its cooling fan to 100% specifically when this node powers on. All three Proxmox nodes in the cluster share one upstream power supply feeding 5 USB-C Power Delivery (PD) trigger boards (each rated 65W), which step down to Dell's 19.5V barrel-jack connector via USB-C-to-barrel adapters.

Dell specifies both 65W and 90W adapters as valid for this OptiPlex 3000 Micro configuration (35W CPU) — meaning the 65W PD board this node was using was at the edge of spec, not comfortably above it, before accounting for extra conversion losses in the PD-board/adapter chain. Bringing multiple CPU cores online during ACPI/SMP initialization causes a brief current spike well above steady-state draw — exactly the moment the crash occurred.

**Test:** The node was powered from a dedicated 100W USB-C PD wall brick, bypassing the shared 5-board rig entirely. With `acpi=off` removed:
- The node booted cleanly with all 12 threads available.
- It stayed stable for 2+ minutes idle.
- It survived a 30-second sustained full 12-core stress load with no crash.
- It survived a full reboot cycle with the fix saved to `/etc/default/grub` (not just a one-time GRUB edit), coming back up automatically with 12 cores and no manual intervention.

This confirms the shared PD-board supply — not ACPI or firmware — was the actual root cause of the original crash-loop.

### Decision

Power this node from a dedicated 100W (or higher) USB-C PD supply instead of the shared 5-board PD rig. Keep ACPI enabled (`acpi=off` removed from `GRUB_CMDLINE_LINUX_DEFAULT`) now that the power constraint is resolved, restoring full 12-thread capacity.

### Consequences

**Positive:**
- Full CPU capacity (12 threads) restored on this node — it can now host real VM/LXC workloads instead of sitting idle.
- ACPI-derived power management, thermal management, and CPU frequency scaling are available again.

**Negative:**
- This node now has a different power source than the other two cluster nodes, which still run on the shared PD-board rig. If it's ever moved back onto that shared supply, the original crash-loop will likely return — this isn't a fix to the shared rig itself, just a workaround of moving this one node off it.
- The shared PD-board rig's headroom for the *other* two nodes is unverified. They haven't shown this symptom, but they also haven't been stress-tested at full core count under that supply. If either shows similar instability under heavy load in the future, suspect the same root cause first before troubleshooting software.

**Follow-up worth doing:**
- Confirm what the shared upstream power supply is actually rated for in aggregate (5 boards × 65W = up to 325W) and whether it can sustain that concurrently, in case the other two nodes are also running closer to the edge than expected.

**Planned resolution (not yet done):** Rather than fitting a higher-wattage PD board into this node's slot — the shared power rig's enclosure has individually-sized cutouts for its USB-C connectors, so a differently-shaped board would need a redesign/reprint of that section, and a coupler-cable workaround was considered and rejected as untidy — the plan is instead to **replace this node itself** with a Dell OptiPlex 3080 Micro matching `pve-01`/`pve-03` (both already proven stable on the shared 65W-board rig). The 32GB RAM and 512GB NVMe currently in this node will be transplanted into the replacement; the bare 3000 Micro (board/CPU/case, minimum remaining components) will then be sold. This both restores hardware uniformity across the cluster and removes the power-delivery edge case entirely, at no loss of the RAM/storage capacity this node was originally upgraded for. A dedicated OPNsense-appliance repurpose was considered for the retiring 3000 Micro board and rejected in favor of a straightforward sale.

Once the swap is complete and verified, file a new ADR documenting the result and mark this one superseded.

### Alternatives Considered

See ADR-0101 for the alternatives considered before the power-delivery theory emerged (`noapic`, BIOS update). Both are now moot — the issue was never ACPI/firmware-level, and further kernel-parameter tuning would not have addressed the actual root cause.

---
