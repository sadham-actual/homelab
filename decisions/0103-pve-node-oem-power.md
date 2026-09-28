# ADR-0103: Keep All Three Cluster Nodes and Power Each from a Genuine Dell Adapter

**Date:** 2026-09-28

**Status:** Accepted

**Supersedes:** ADR-0102 (its planned resolution only; its root-cause finding stands)

### Context

ADR-0102 established that `pve-02` (OptiPlex 3000 Micro, i5-12500T) crash-looped at boot because the shared power rig could not deliver its startup current: one upstream supply feeding 5x 65W USB-C PD trigger boards, each stepping down to a Dell barrel through a USB-C-to-barrel adapter. `pve-02` has run cleanly on a dedicated 100W USB-C PD brick ever since. ADR-0102 then planned to **replace** the 3000 Micro with a third 3080 Micro and sell it, because the rig's enclosure has fixed cutouts for 65W boards and could not take a bigger one.

That plan assumed the custom rig stays. Moving the lab into a 19" rack with a PDU removes that assumption. Stock Dell AC adapters can sit on a shelf behind the nodes, one per PDU outlet, and the power constraint becomes a parts choice instead of a reason to replace hardware.

Measured numbers from [Proxmox Cluster Hardware](../docs/02-hardware/proxmox-node.md) size the adapters:

| Node | Platform idle | Loaded / PL2 | Adapter |
|---|---|---|---|
| `pve-01`, `pve-03` (i5-10500T) | 5.3 W | 56 W measured peak, PL2 68 W | 65 W is sufficient, 90 W acceptable |
| `pve-02` (i5-12500T) | 21.8 W | ~72 W estimated, PL2 77 W | **90 W required** |

Dell lists both 65W and 90W adapters for the 3000 Micro. The measurements show the 65W option is the wrong one for a node that boots all 12 threads unattended.

### Decision

- **Keep all three nodes**, including the 3000 Micro. It is not replaced or sold.
- **Retire the shared PD-board rig.** Power every node from its own **genuine Dell AC adapter**, plugged into the rack PDU: **90W for `pve-02`**, and 65W or 90W for the 3080 Micros. Standardising on 90W for all three is acceptable and makes adapters interchangeable spares.
- Buy genuine adapters only. Dell barrel adapters carry an ID line that reports wattage to the BIOS, and knock-offs that misreport it can trigger adapter warnings or power-limit the CPU, which is the failure class this ADR exists to close. Confirm the barrel size against each model before ordering.

### Consequences

**Positive:**
- The power-delivery fault is closed on every node with OEM parts, rather than worked around on one.
- Removes a **cluster-wide single point of failure**: all three nodes previously shared one upstream supply, so its failure would have dropped quorum and every guest at once. Each node now fails independently.
- No hardware is sold or migrated. `pve-02` keeps its 32GB RAM and 512GB NVMe, and stays the largest node.
- Each node gets its own PDU outlet, so a switched PDU can power-cycle one node remotely.

**Negative:**
- Hardware uniformity is **not** restored. The cluster stays mixed 10th/12th-gen, so guests on `cpu: host` still cannot live-migrate between generations. Guests that need to migrate should use a common CPU type (`x86-64-v3`, supported by both).
- Three adapters and three PDU outlets instead of one supply, plus shelf space behind the nodes in the rack.
- BIOS versions keep diverging across two platform lines (3080 and 3000), so the flash procedure has to be run per platform.

**Follow-up:**
- After cutover, re-verify `pve-02` with the same checks that confirmed ADR-0102: several cold boots at full thread count, then corosync flap and TOTEM retransmit counts over at least 12 hours.

### Alternatives Considered

**Replace the 3000 Micro with a third 3080 Micro (ADR-0102's plan):**
- Pros: identical nodes, live migration with `cpu: host`, the proven 65W budget
- Cons: cost of a replacement node plus the hassle of selling the old one, and it keeps the custom rig as a shared point of failure
- Why rejected: with OEM adapters the power edge case goes away without replacing anything

**Keep the custom rig and redesign it for a 100W board:**
- Pros: one supply, tidy power for the micros
- Cons: requires reprinting the enclosure, keeps the conversion chain that caused the fault, and keeps the single point of failure
- Why rejected: more work for a worse result than stock adapters

**Keep `pve-02` on its 100W USB-C PD brick permanently:**
- Pros: already proven stable, no purchase
- Cons: a USB-C-to-barrel conversion chain instead of an OEM part, and the 3080s stay on the shared rig
- Why rejected: fixes one node and leaves the shared rig in service for the other two

---
