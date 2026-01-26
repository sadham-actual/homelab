# Proxmox Node Hardware

## Specifications

| Component | Details |
|-----------|---------|
| **Model** | Dell OptiPlex 3080 Micro |
| **CPU** | Intel Core i5-10500T (6C/12T, Base 2.3GHz, Boost 3.8GHz) |
| **RAM** | 40GB DDR4 (expandable) |
| **Storage** | 256GB SSD (NVMe or SATA) |
| **Network** | 1x Gigabit Ethernet (Intel I219-LM) |
| **Form Factor** | Ultra Small Form Factor (1.0L) |
| **Power** | ~65W TDP |
| **OS** | Proxmox VE 8.x (planned) |

## Hardware Details

### CPU: Intel Core i5-10500T
- **Architecture:** Comet Lake (10th Gen)
- **Cores/Threads:** 6C/12T
- **Base Clock:** 2.3 GHz
- **Boost Clock:** Up to 3.8 GHz (single core), 3.5 GHz (all cores)
- **TDP:** 35W (T-series = low power variant)
- **Cache:** 12MB Intel Smart Cache
- **iGPU:** Intel UHD Graphics 630
  - Could be used for GPU passthrough to VMs if needed
  - Not as powerful as Xeon's P750, but sufficient for basic transcoding
- **Features:** VT-x, VT-d (virtualization extensions)

**Performance Notes:**
- Perfect for homelab virtualization
- 6 cores provides good VM density
- Low TDP keeps power consumption and heat down
- Sufficient for multiple VMs + k3s cluster
- Can handle 4-6 simultaneous VMs comfortably

**Comparison to TrueNAS:**
- TrueNAS: 8C/16T Xeon (more cores, better for parallel Docker workloads)
- Proxmox: 6C/12T i5 (sufficient for VMs, lower power)
- Combined: 14 cores/28 threads total compute

### Memory: 40GB DDR4
- **Configuration:** Likely 1x 32GB + 1x 8GB or 2x 16GB + 1x 8GB
- **Speed:** DDR4-2666 or DDR4-2933 (depending on configuration)
- **ECC:** No (consumer platform, not critical for VMs like it is for ZFS)
- **Maximum:** 64GB (2x 32GB SO-DIMM)

**Memory Allocation Strategy:**
- **Proxmox Host:** Reserve 4-6GB for hypervisor
- **Available for VMs:** ~34-36GB
- **Typical VM allocation:**
  - Ubuntu Server VM: 2-4GB
  - k3s control plane: 4-6GB
  - k3s workers: 2-4GB each
  - Windows VM (testing): 4-8GB
  - Monitoring VM: 2GB

**Example Configuration:**
```
Proxmox Host:        6GB
k3s single node:     8GB
Ubuntu test VM:      4GB
Monitoring VM:       2GB
Windows test VM:     8GB (when needed)
Free/Buffer:        12GB
---
Total:              40GB
```

### Storage: 256GB SSD
- **Capacity:** 256GB
- **Type:** Likely NVMe M.2 or SATA SSD (Dell varies by config)
- **Purpose:** Proxmox OS + local VM storage
- **Usage Strategy:**
  - Proxmox OS: ~20GB
  - Local VM templates: ~20GB
  - Active VM disks (testing): ~50-100GB
  - Remaining: ~100-150GB for snapshots/overhead

**Storage Strategy:**
- Use for Proxmox OS and fast-access VMs
- Use TrueNAS iSCSI for production VM storage
- Use TrueNAS NFS for backups and ISOs
- Keep local storage for VMs that need low-latency (testing, dev)

**Future Expansion:**
- Dell 3080 Micro has limited internal expansion
- Could add 2.5" SATA SSD in some configurations
- Primary storage expansion via TrueNAS network storage

### Network: Gigabit Ethernet
- **Controller:** Intel I219-LM
- **Speed:** 1 Gigabit Ethernet
- **Ports:** Single RJ45
- **Notes:**
  - Sufficient for VM traffic and management
  - Will be bottleneck for iSCSI storage (2.5Gbps would be better)
  - Consider USB 3.0 to 2.5GbE adapter for storage VLAN

**Network Considerations:**
- Current: Single GbE adequate for learning and testing
- Limitation: iSCSI storage traffic limited to ~100 MB/s
- Workaround: Use NFS for less I/O intensive VMs
- Future: Add USB-to-2.5GbE adapter (~$30) for storage network

**VLAN Configuration (Future):**
- Single NIC with VLAN tagging (802.1Q)
- Proxmox can create virtual bridges for each VLAN
- VMs can be assigned to specific VLANs

### Form Factor: Dell OptiPlex 3080 Micro
- **Dimensions:** ~182mm x 178mm x 36mm (1.0L volume)
- **Mounting:** VESA mount compatible
- **Expansion:** Very limited internal space
- **Connectivity:**
  - Multiple USB 3.2 ports (front and rear)
  - DisplayPort and HDMI (for iGPU)
  - Audio jacks
  - Optional WiFi/Bluetooth (depending on config)

**Physical Considerations:**
- Compact and quiet (good for home environment)
- Low power consumption (~20-40W typical, up to 65W peak)
- Easy to place near network equipment
- Minimal cooling noise under normal load

## Planned Configuration

### Proxmox VE Installation
- **Version:** Proxmox VE 8.x (latest stable)
- **Installation Media:** USB drive with Proxmox ISO
- **Disk Layout:**
  - Full disk for Proxmox (LVM-thin)
  - Or partition: 50GB Proxmox + remainder for local VM storage
- **Network:** Static IP on management VLAN (192.168.10.X after network upgrade)

### Storage Configuration

**Local Storage (256GB SSD):**
- `/dev/sda1` - Proxmox OS and packages
- `/dev/sda2` - Local LVM for VM disks
- Storage type: LVM-Thin (allows overprovisioning and snapshots)

**TrueNAS Integration:**
1. **NFS Mount for Backups/ISOs**
   - TrueNAS dataset: `/tank/proxmox/backups`
   - Mount point: `/mnt/pve/truenas-backups`
   - Purpose: VM backups, container templates, ISO images

2. **iSCSI LUN for VM Storage**
   - TrueNAS dataset: `/tank/proxmox/vms`
   - LUN size: 500GB-1TB (carved from tank pool)
   - Purpose: Production VM disk images
   - Protocol: iSCSI over storage VLAN (future)

3. **NFS Share for k3s Persistent Volumes**
   - TrueNAS dataset: `/tank/kubernetes/pvs`
   - Mount: Direct from k3s CSI driver
   - Purpose: Persistent storage for Kubernetes pods

### Network Configuration

**Phase 1 (Current Network):**
- Single interface on 192.168.1.0/24
- DHCP initially, then set static IP
- Access via IP or hostname (proxmox.local or similar)
- No VLAN segmentation yet

**Phase 2 (After OPNsense):**
- VLAN 10 (Management): 192.168.10.X
- VLAN 20 (Storage): 192.168.20.X (via USB adapter or VLAN tagging)
- VLAN 30 (Services): VMs attached to this bridge
- Virtual bridges in Proxmox for each VLAN

### VM Planning

**Initial VMs (First Month):**
1. **Ubuntu Server 24.04 LTS** (Template)
   - 2 vCPU, 2GB RAM, 20GB disk
   - Cloud-init enabled
   - Purpose: Template for cloning test VMs

2. **Rocky Linux 9** (Learning)
   - 2 vCPU, 2GB RAM, 20GB disk
   - RHEL-based learning for certifications
   - Practice systemd, firewalld, SELinux

3. **Uptime Kuma** (Monitoring)
   - 1 vCPU, 1GB RAM, 10GB disk
   - Monitor homelab services
   - Migration target from TrueNAS Docker

**Future VMs:**
- k3s single-node cluster (4-8GB RAM)
- Windows 10/11 (testing, 8GB RAM)
- Additional Linux distros for learning
- OPNsense firewall (2 vCPU, 2GB RAM)

## Performance Expectations

### VM Density
- **Conservative:** 4-5 simultaneous VMs (leaving headroom)
- **Aggressive:** 6-8 VMs (if sized appropriately)
- **Realistic:** 3-4 active VMs + k3s cluster

### Limitations
- **CPU:** Shared among all VMs, expect some contention under heavy load
- **RAM:** 40GB is generous but finite - size VMs appropriately
- **Storage:** 256GB local limits number of VMs unless using TrueNAS
- **Network:** 1GbE shared across all VM traffic

### Bottlenecks
- **Storage I/O:** Local SSD is fast, but iSCSI over 1GbE will be slower
- **Network:** Single NIC at 1Gbps is the primary limitation
- **CPU:** Should be fine for typical homelab workloads

## Expansion Options

### Immediate (No Cost)
- Optimize VM sizing (don't over-allocate resources)
- Use TrueNAS storage to offload VM disks
- Leverage LXC containers instead of VMs where appropriate

### Low Cost ($30-100)
- USB 3.0 to 2.5GbE adapter for storage network
- Additional RAM (8GB or 16GB modules)
- External USB SSD for additional VM storage

### Medium Cost ($100-300)
- Second identical Dell 3080 Micro for Proxmox cluster
- Small managed switch for VLAN support
- UPS for both Proxmox and TrueNAS

### High Cost ($300+)
- Upgrade to Dell 5080 or 7080 with better CPU/RAM
- 10GbE network infrastructure
- Larger capacity NVMe drives

## Comparison: TrueNAS vs Proxmox

| Aspect | TrueNAS Server | Proxmox Node |
|--------|----------------|--------------|
| **Role** | Storage + Services | Compute + VMs |
| **CPU** | Xeon W-1370 (8C/16T) | i5-10500T (6C/12T) |
| **RAM** | 32GB ECC | 40GB non-ECC |
| **Storage** | 8TB RAIDZ1 | 256GB local SSD |
| **Network** | 2.5GbE | 1GbE |
| **Power** | 80W typical | 35W typical |
| **Workload** | Docker, Storage, Transcode | VMs, k3s, Testing |
| **Criticality** | High (family services) | Medium (learning) |

## Maintenance Plan

### Initial Setup (Week 1)
- Install Proxmox VE from USB
- Configure static IP
- Update system packages
- Configure TrueNAS NFS mount for backups
- Set up SSH access and firewall

### Regular Maintenance
- **Weekly:** Check VM resource usage, review logs
- **Monthly:** Update Proxmox packages, backup VM configs
- **Quarterly:** Test restore procedures, review capacity
- **Annually:** Evaluate hardware upgrade needs

### Backup Strategy
- VM backups to TrueNAS NFS share (weekly)
- Proxmox config backup (before major changes)
- VM snapshots before updates/changes
- Document all major configuration changes in Git

## Learning Objectives

This hardware will enable learning:
1. **Hypervisor management** (Proxmox web UI, CLI tools)
2. **Virtual networking** (bridges, VLANs, firewall)
3. **Storage integration** (iSCSI, NFS, LVM)
4. **VM lifecycle** (creation, snapshots, cloning, migration)
5. **Resource management** (CPU/RAM allocation, balancing)
6. **High availability concepts** (when second node added)

---

*Last Updated: 2025-01-26*