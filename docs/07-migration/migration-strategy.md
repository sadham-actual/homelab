# Service Migration Strategy

## Migration Philosophy

**Guiding Principles:**
1. **Stability First:** Never compromise family-critical services (Jellyfin, Immich)
2. **Learn by Doing:** Migrate incrementally to understand each component
3. **Parallel Operation:** Run old and new simultaneously before cutover
4. **Document Everything:** Capture learnings and rollback procedures
5. **Measure Success:** Define metrics before migration, validate after

**Risk Tolerance:**
- **Zero tolerance:** Family services (Jellyfin, Immich, NPM)
- **Low risk:** Media automation (*arr stack, qBittorrent)
- **Experimental:** New services, non-critical utilities

## Migration Phases Overview

### Phase 0: Pre-Migration Foundation (Week 0)
**Goal:** Prepare infrastructure and documentation before any changes

**Tasks:**
- Set up automated TrueNAS snapshots
- Document all current service configurations
- Test TrueNAS backup/restore procedures
- Deploy Uptime Kuma for service monitoring
- Create baseline performance metrics

**Success Criteria:**
- All services documented in Git
- Hourly snapshots running on TrueNAS
- Monitoring covers all critical services
- Rollback tested and verified

### Phase 1: Proxmox Foundation (Weeks 1-2)
**Goal:** Get Proxmox operational with TrueNAS integration

**Tasks:**
- Install Proxmox VE on Dell 3080 Micro
- Configure static IP and networking
- Set up TrueNAS NFS mount for backups/ISOs
- Upload Ubuntu and Rocky Linux ISOs
- Create first test VM (Ubuntu Server)

**Success Criteria:**
- Proxmox web UI accessible
- Can create/delete VMs successfully
- TrueNAS storage mounted and working
- Documentation of Proxmox setup complete

**No service migrations yet** - pure learning phase

### Phase 2: First Service Migration (Weeks 3-4)
**Goal:** Successfully migrate first non-critical service to Proxmox VM

**Target Service:** Uptime Kuma
**Rationale:** 
- Simple single-container app
- Not family-critical (monitoring tool)
- Easy to validate (just needs to ping services)
- Low complexity (no storage dependencies)

**Migration Steps:**
1. Create Ubuntu Server VM (2 vCPU, 2GB RAM, 20GB disk)
2. Install Docker and Docker Compose on VM
3. Deploy Uptime Kuma via Docker Compose
4. Import monitors from TrueNAS Uptime Kuma
5. Run parallel for 1 week, comparing results
6. Cutover: Update bookmarks/dashboards
7. Stop TrueNAS Uptime Kuma after 1 week validation

**Rollback Plan:** 
- Restart TrueNAS Uptime Kuma container
- Delete Proxmox VM
- Time to rollback: <5 minutes

**Success Criteria:**
- VM Uptime Kuma monitors all services
- No false alerts or missed downtime
- Performance equivalent to container
- Documentation updated with VM setup

### Phase 3: Second Migration - VPN Download VM (Weeks 5-6)
**Goal:** Migrate more complex service with network requirements

**Target Service:** qBittorrent + VPN
**Rationale:**
- Network isolation benefit (VPN in dedicated VM)
- Downloads can pause briefly without issue
- Good learning for network configuration
- Prepares for *arr stack migration

**Migration Steps:**
1. Create Ubuntu VM (2 vCPU, 4GB RAM, 50GB disk)
2. Configure WireGuard VPN (ProtonVPN)
3. Install qBittorrent in Docker
4. Mount `/tank/media/downloads` via NFS
5. Test VPN: Verify IP is ProtonVPN, no leaks
6. Migrate download queue (export/import from TrueNAS qBit)
7. Update *arr apps to point to new qBittorrent
8. Monitor downloads for 1 week
9. Cutover after validation

**Rollback Plan:**
- Update *arr apps back to TrueNAS qBittorrent
- Delete Proxmox VM
- Resume TrueNAS qBittorrent
- Time to rollback: ~10 minutes

**Success Criteria:**
- VPN always active (kill switch working)
- Downloads complete successfully
- *arr apps can add/manage torrents
- Performance equal or better than TrueNAS
- No IP leaks detected

### Phase 4: Media Automation Stack (Weeks 7-10)
**Goal:** Migrate entire *arr stack to Proxmox

**Target Services:**
- Sonarr
- Radarr
- Lidarr
- Prowlarr
- Bazarr
- FlareSolverr
- Profilarr

**Deployment Options:**

**Option A: Single VM with all services**
- VM specs: 4 vCPU, 8GB RAM, 100GB disk
- All *arr apps in Docker Compose on one VM
- Pros: Simple, single point of management
- Cons: All services share resources, no isolation

**Option B: Individual VMs per service**
- 7 separate VMs
- Pros: Better isolation, can size individually
- Cons: More management overhead, resource inefficient

**Recommended: Option A** (single VM, can split later if needed)

**Migration Steps:**
1. Create *arr-stack VM (4 vCPU, 8GB RAM, 100GB disk)
2. Mount `/tank/media` and `/tank/configs` via NFS
3. Install Docker and Docker Compose
4. Deploy all *arr services via single compose file
5. Restore *arr databases from TrueNAS backups
6. Verify indexers, download clients configured correctly
7. Test manual search and download in each *arr app
8. Run parallel with TrueNAS *arr stack for 1-2 weeks
9. Monitor: No missed releases, downloads work, Jellyfin updates
10. Cutover: Stop TrueNAS *arr containers
11. Update bookmarks and access methods

**Rollback Plan:**
- Stop Proxmox *arr VM
- Restart TrueNAS *arr containers
- Restore latest database backups
- Time to rollback: ~15-20 minutes

**Success Criteria:**
- All *arr apps functional and searching
- Downloads trigger automatically
- Jellyfin library updates when media added
- No missed episodes/movies during parallel run
- Performance equal or better than TrueNAS

### Phase 5: Kubernetes Foundation (Weeks 11-14)
**Goal:** Deploy single-node k3s cluster on Proxmox

**No service migrations yet** - pure learning phase

**Tasks:**
1. Create k3s VM (4 vCPU, 8GB RAM, 50GB disk)
2. Install k3s (single-node cluster)
3. Configure TrueNAS NFS for persistent volumes
4. Deploy sample apps (nginx, whoami)
5. Set up kubectl on workstation
6. Deploy simple monitoring (metrics-server)
7. Learn kubectl, pods, deployments, services

**Success Criteria:**
- k3s cluster operational
- Can deploy and access pods
- Persistent storage works with TrueNAS NFS
- Basic monitoring in place

### Phase 6: First k8s Service (Weeks 15-16)
**Goal:** Migrate first service to Kubernetes

**Target Service:** Tracktor (or Jellyseerr)
**Rationale:**
- Simple web app, low criticality
- Stateless or minimal state
- Good learning for k8s deployments
- No complex dependencies

**Migration Steps:**
1. Create Kubernetes manifests (deployment, service, ingress)
2. Deploy to k3s cluster
3. Configure ingress (Traefik or Nginx Ingress Controller)
4. Test access from internal network and Tailscale
5. Run parallel with TrueNAS version for 1 week
6. Cutover: Update NPM or bookmarks
7. Stop TrueNAS container

**Success Criteria:**
- App functional in k8s
- Can update deployment (rolling update)
- Ingress routing works correctly
- Persistent data survives pod restart (if applicable)

### Phase 7: Network Upgrade Planning (Weeks 17-20)
**Goal:** Plan and prepare for network segmentation

**Tasks:**
- Research and select managed switch
- Design VLAN architecture
- Plan OPNsense deployment (VM vs hardware)
- Document network migration steps
- Purchase hardware (switch, possibly APs)
- No service disruption during planning

**Deliverables:**
- Network design document
- Hardware shopping list
- Migration runbook
- Rollback procedures

### Phase 8: Network Migration (Weeks 21-24)
**Goal:** Implement VLANs and OPNsense

**Major Change:** This will affect entire network

**Tasks:**
1. Install managed switch
2. Deploy OPNsense (VM on Proxmox or dedicated hardware)
3. Configure VLANs on switch
4. Migrate devices to VLANs incrementally
5. Set up firewall rules
6. Test inter-VLAN routing
7. Deploy WiFi APs (if upgrading from Deco)

**Rollback Plan:**
- Keep Deco system in place during transition
- Can fall back to Deco if OPNsense fails
- Document exact steps to revert

**Success Criteria:**
- All devices on appropriate VLANs
- Firewall rules working correctly
- No loss of service during migration
- Performance equal or better
- Family doesn't notice any disruption

## Services That Stay on TrueNAS

### Permanently on TrueNAS
These services should NOT migrate:

**Jellyfin**
- **Reason:** Requires iGPU passthrough for transcoding
- **Keep on TrueNAS:** Direct hardware access, proven stable
- **Alternative:** Could migrate to Proxmox VM with GPU passthrough, but adds complexity

**Immich**
- **Reason:** 250GB of photos, heavy ML processing, direct dataset access
- **Keep on TrueNAS:** Storage-intensive, benefits from ZFS, family-critical
- **Alternative:** Could use TrueNAS NFS, but performance may suffer

**Tailscale**
- **Reason:** Core infrastructure for remote access
- **Keep on TrueNAS:** Always-on, survives Proxmox reboots
- **Alternative:** Could move to OPNsense or dedicated Pi later

**File Browser**
- **Reason:** Direct dataset access
- **Keep on TrueNAS:** Native file management

**Dockge**
- **Reason:** Manages remaining TrueNAS containers
- **Keep on TrueNAS:** No benefit to moving

**Watchtower**
- **Reason:** Updates TrueNAS containers
- **Keep on TrueNAS:** Applies to local containers only

### Conditionally Stay on TrueNAS

**Nginx Proxy Manager**
- **Initial:** Keep on TrueNAS (critical, proven working)
- **Future:** Consider moving to OPNsense or dedicated VM
- **Benefit of moving:** Better separation, easier to manage with OPNsense

**NetBird**
- **Current:** Experimental, not actively used
- **Decision:** Decommission in favor of Tailscale

## Migration Decision Matrix

For each service, evaluate:

| Criteria | Stay TrueNAS | Move to Proxmox VM | Move to k8s |
|----------|--------------|-----------------------|-------------|
| **Storage-heavy** (>100GB) | ✅ | ❌ | ❌ |
| **Direct dataset access needed** | ✅ | ❌ | ❌ |
| **Hardware requirement** (GPU) | ✅ | ⚠️ (with passthrough) | ❌ |
| **Family-critical** | ✅ | ⚠️ (after proven) | ❌ |
| **Stateless web app** | ❌ | ⚠️ | ✅ |
| **Learning opportunity** | ❌ | ✅ | ✅ |
| **Complex dependencies** | ⚠️ | ✅ | ❌ |
| **Network isolation benefit** | ❌ | ✅ | ⚠️ |

## Parallel Operation Guidelines

### Why Run in Parallel?
- Validate new service matches old functionality
- Catch unexpected issues before cutover
- Allow time to adjust to new configuration
- Maintain service availability during testing
- Build confidence in new platform

### Parallel Duration by Service Type
- **Simple services:** 3-7 days
- **Medium complexity:** 1-2 weeks  
- **Critical services:** 2-4 weeks
- **Complex dependencies:** 4+ weeks

### What to Monitor During Parallel
1. **Functionality:** All features work in new environment
2. **Performance:** Response times, resource usage
3. **Reliability:** Uptime, error rates
4. **Dependencies:** Other services still communicate correctly
5. **User Experience:** Family doesn't notice issues

### Cutover Checklist
Before switching from old to new service:
- [ ] New service fully functional for parallel duration
- [ ] No errors or warnings in logs
- [ ] Performance meets or exceeds old service
- [ ] All integrations tested
- [ ] Backups of old configuration saved
- [ ] Rollback plan documented and tested
- [ ] Monitoring alerts configured for new service
- [ ] Family/users notified if applicable

## Rollback Procedures

### General Rollback Process
1. **Stop new service** (VM or k8s pod)
2. **Start old service** (TrueNAS container)
3. **Restore configuration** (from backup if changed)
4. **Update dependencies** (point back to old service)
5. **Verify functionality** (test all features)
6. **Document failure** (lessons learned)

### Time to Rollback Targets
- **Simple service:** <5 minutes
- **Medium complexity:** <15 minutes
- **Critical service:** <30 minutes
- **Network change:** <1 hour

### When to Rollback
- New service has recurring errors
- Performance significantly worse
- Critical feature missing or broken
- Family reports issues
- Migration taking longer than planned
- Unexpected dependencies discovered

### Rollback Testing
- Test rollback procedure during parallel phase
- Don't wait until production to try rollback
- Time the rollback to ensure it's fast enough
- Document any issues encountered

## Risk Management

### High-Risk Migrations
Services that are risky to migrate:
1. **Jellyfin** - Family streaming, requires GPU
2. **Immich** - 80k photos, ML processing
3. **Nginx Proxy Manager** - All external traffic
4. **qBittorrent** - VPN must never fail

**Mitigation:**
- Extra-long parallel periods
- Extensive testing before cutover
- Multiple rollback drills
- Consider NOT migrating (Jellyfin, Immich)

### Medium-Risk Migrations
Services with some risk:
1. ***arr stack** - Complex interdependencies
2. **OctoPrint** - Physical hardware connection
3. **n8n** - Automation workflows

**Mitigation:**
- Standard parallel period (1-2 weeks)
- Test all integrations thoroughly
- Document dependencies carefully

### Low-Risk Migrations
Services safe to migrate:
1. **Uptime Kuma** - Monitoring tool, non-critical
2. **Tracktor** - Package tracking, minimal state
3. **Navidrome** - Music streaming, alternative to Jellyfin

**Mitigation:**
- Short parallel period (3-7 days)
- Standard testing procedures

## Communication Plan

### Family Communication
**Before Migration:**
- "I'm upgrading our media server over the next few weeks"
- "You might notice brief interruptions, I'll let you know"
- "Let me know if Jellyfin acts weird"

**During Migration:**
- "Testing new setup, let me know if you see issues"
- "If Jellyfin stops working, text me immediately"

**After Migration:**
- "Upgrade complete, everything should work the same"
- "Let me know if anything seems different"

### Maintenance Windows
**For family-critical services:**
- Schedule changes during low-usage times (late night, early morning)
- Avoid Friday evenings, weekends (high Jellyfin usage)
- Keep changes under 15 minutes when possible

**For non-critical services:**
- Anytime is fine
- Still notify if major changes

## Success Metrics

### Per-Service Metrics
**Before Migration (Baseline):**
- Resource usage (CPU, RAM, network)
- Response time (HTTP requests)
- Error rate (from logs)
- Uptime percentage

**After Migration (Comparison):**
- Same metrics, compared to baseline
- Goal: Equal or better performance
- Acceptable: Within 10% of baseline
- Unacceptable: >20% worse performance

### Overall Migration Success
- **Timeline:** Completed within planned timeframe
- **Stability:** No service outages >15 minutes
- **Family Impact:** Zero complaints about availability
- **Learning:** Documented lessons and new skills gained
- **Rollbacks:** <2 rollbacks total (indicates good planning)

## Documentation Requirements

### Per-Service Documentation
For each migrated service, document:
1. **Migration date and duration**
2. **Old configuration** (Docker Compose, env vars)
3. **New configuration** (VM specs, k8s manifests)
4. **Changes made** (what's different)
5. **Issues encountered** (and how solved)
6. **Performance comparison** (before/after metrics)
7. **Lessons learned** (what went well, what didn't)

### Store in Git
- `/docs/07-migration/` - Strategy and planning
- `/docs/07-migration/completed/` - Completed migrations
- `/docs/07-migration/lessons-learned/` - Retrospectives
- `/configs/` - All configuration files (sanitized)

## Timeline Summary

| Phase | Weeks | Focus | Services Migrated |
|-------|-------|-------|-------------------|
| 0 | Week 0 | Preparation | None (setup) |
| 1 | 1-2 | Proxmox Setup | None (learning) |
| 2 | 3-4 | First Migration | Uptime Kuma |
| 3 | 5-6 | VPN VM | qBittorrent |
| 4 | 7-10 | *arr Stack | 7 services |
| 5 | 11-14 | k8s Setup | None (learning) |
| 6 | 15-16 | First k8s | Tracktor |
| 7 | 17-20 | Network Planning | None (planning) |
| 8 | 21-24 | Network Upgrade | All (VLAN migration) |

**Total Timeline:** ~6 months from start to network upgrade complete

**Flexible Timeline:** 
- Can pause between phases
- Can extend phases if needed
- No pressure to rush
- Learning is the priority

## Next Steps

1. Complete Phase 0 preparation tasks
2. Set up automated snapshots on TrueNAS
3. Deploy Uptime Kuma for monitoring
4. Document all current service configurations
5. Review and adjust timeline based on availability

---

*Last Updated: 2025-01-26*