# ADR-0001: Use TrueNAS for Centralized Storage

**Date:** 2025-01-26

**Status:** Accepted

### Context

The homelab requires centralized storage for:
- Media files (1.22TB for Jellyfin)
- Photos and videos (250GB for Immich, 80k+ files)
- Configuration backups
- VM storage (for Proxmox)
- Container persistent volumes

We have existing TrueNAS SCALE server with:
- Xeon W-1370 CPU with iGPU (QuickSync)
- 32GB ECC RAM
- 3x 4TB RAIDZ1 array (~8TB usable)
- Proven stable with current Docker workloads

**Options:**
1. Use TrueNAS for storage (current state)
2. Use Proxmox ZFS for all storage
3. Split storage between TrueNAS and Proxmox

### Decision

**Use TrueNAS as the primary storage server** for all persistent data in the homelab.

Proxmox will access TrueNAS storage via:
- **iSCSI** for VM disk images (performance-critical VMs)
- **NFS** for backups, ISOs, and Kubernetes persistent volumes

### Consequences

**Positive:**
- Single source of truth for all data
- ZFS benefits (snapshots, integrity, compression) centralized
- TrueNAS web UI simplifies storage management
- ECC RAM protects data integrity (critical for ZFS)
- Existing proven stable platform
- Hardware transcoding (iGPU) stays with media files

**Negative:**
- Network dependency (storage over network introduces latency)
- Single point of failure (if TrueNAS down, all storage inaccessible)
- 1GbE NIC on Proxmox may bottleneck iSCSI (mitigated with NFS for less critical workloads)

**Mitigation:**
- Use NFS instead of iSCSI for non-critical VMs
- Plan for USB 2.5GbE adapter on Proxmox for dedicated storage network
- Regular backups to external location (USB, cloud)
- UPS for graceful shutdowns during power outages

### Alternatives Considered

**Option 2: Proxmox ZFS for all storage**
- Pros: Direct storage access (no network), simpler architecture
- Cons: Lose TrueNAS features, only 256GB local storage on Proxmox, no ECC RAM on Proxmox, would need to migrate all existing data

**Option 3: Split storage**
- Pros: Reduce network traffic, some local fast storage
- Cons: Complexity (manage two storage systems), data scattered, harder to backup

**Why Rejected:** TrueNAS is already working well, has sufficient capacity, and provides superior data protection with ECC RAM and mature ZFS implementation.

---