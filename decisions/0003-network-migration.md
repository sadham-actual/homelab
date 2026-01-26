# ADR-0003: Two-Phase Network Migration (Keep Deco, Then OPNsense)

**Date:** 2025-01-26

**Status:** Accepted

### Context

Current network is flat (192.168.1.0/24) using TP-Link Deco mesh system. Goal is enterprise-style network with VLANs, proper segmentation, and security.

**Ideal state:**
- OPNsense firewall/router
- Managed switch with VLAN support
- Proper WiFi access points
- 5 VLANs for segmentation

**Challenge:**
- Major network overhaul is disruptive (affects whole family)
- Learning curve for OPNsense, VLANs, firewall rules
- Risk of breaking everything if done wrong
- Need working network while building skills

### Decision

**Implement two-phase network migration:**

**Phase 1 (Months 1-6): Keep Current Network**
- Use existing Deco mesh
- No VLANs, no segmentation
- Focus on Proxmox, VMs, k3s learning
- Use Tailscale for secure access
- Plan and document future network design

**Phase 2 (Month 6+): Network Upgrade**
- Deploy OPNsense (VM on Proxmox or dedicated hardware)
- Purchase and configure managed switch
- Implement VLAN architecture
- Replace Deco with proper WiFi APs
- Migrate devices VLAN-by-VLAN (incremental)
- Keep Deco as fallback during migration

### Consequences

**Positive:**
- Lower risk (changes are incremental)
- Family not disrupted during learning phase
- Time to practice in parallel environment
- Can perfect OPNsense config before cutover
- Rollback plan (Deco stays in place initially)
- Focus on one major change at a time

**Negative:**
- Longer timeline to reach ideal state (6+ months vs. immediate)
- Limited network segmentation during Phase 1 (security concern)
- May need to reconfigure some services twice (once for flat, once for VLANs)

**Mitigation:**
- Use Tailscale for secure remote access during Phase 1
- Document all configurations in Git (easy to replay in Phase 2)
- Test OPNsense in VM during Phase 1 (no production impact)

### Alternatives Considered

**Immediate full migration:**
- Pros: Reach ideal state faster, proper security immediately
- Cons: High risk of family disruption, steeper learning curve, harder to troubleshoot, no fallback
- Why rejected: Too risky for family-used network, too much to learn at once

**Never upgrade network:**
- Pros: Simple, no effort, no risk
- Cons: Poor security, no segmentation, doesn't teach enterprise networking skills
- Why rejected: Defeats learning goals, leaves security gaps

---
