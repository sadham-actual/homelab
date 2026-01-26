# ADR-0004: Jellyfin and Immich Remain on TrueNAS

**Date:** 2025-01-26

**Status:** Accepted

### Context

Migration plan involves moving services from TrueNAS to Proxmox VMs or Kubernetes. Two services are particularly complex:

**Jellyfin:**
- Requires iGPU (Intel QuickSync) for hardware transcoding
- Handles 1.22TB media library
- Family actively uses for streaming
- Direct dataset access for performance

**Immich:**
- 80,000+ photos and videos (250GB)
- Machine learning processing (face/object recognition)
- Active photo uploads from mobile devices
- Direct dataset access for performance

**Options:**
1. Keep both on TrueNAS
2. Migrate both to Proxmox VMs
3. Migrate Jellyfin with GPU passthrough
4. Hybrid approach

### Decision

**Keep Jellyfin and Immich on TrueNAS permanently.**

Do not migrate these services as part of the standard migration plan.

### Consequences

**Positive:**
- Zero disruption to family (Jellyfin keeps working)
- No complexity of GPU passthrough (Jellyfin)
- Direct storage access remains fast (both services)
- No risk of data corruption during migration (80k photos)
- Proven stable configuration continues to work
- More resources available on Proxmox for learning workloads

**Negative:**
- TrueNAS remains hybrid server (storage + some services)
- Miss learning opportunity for GPU passthrough (can learn later if desired)
- Two places to manage services (TrueNAS + Proxmox)

**Neutral:**
- Can always migrate later if desired (not a permanent decision)

### Alternatives Considered

**Migrate Jellyfin with GPU passthrough:**
- Pros: Consolidate compute on Proxmox, learn GPU passthrough
- Cons: Complex (iGPU passthrough tricky), risk of breaking family streaming, slower storage access over network
- Why rejected: High risk for low reward, family uses Jellyfin daily

**Migrate Immich to VM:**
- Pros: Consolidate services, learn more complex migrations
- Cons: Slower storage access (80k files over NFS), risk of photo data corruption, ML processing may be slower
- Why rejected: Photos are irreplaceable, not worth the risk

**Migrate to k8s:**
- Pros: Learn complex stateful apps in Kubernetes
- Cons: Even more complexity, requires PVs over NFS (slower), harder to troubleshoot
- Why rejected: Unnecessary complexity for stable, working services

---