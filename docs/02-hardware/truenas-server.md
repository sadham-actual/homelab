# TrueNAS Server Hardware

## Specifications

| Component | Details |
|-----------|---------|
| **Motherboard** | ASRock W480 Creator |
| **CPU** | Intel Xeon W-1370 (8C/16T, Base 2.9GHz, Boost 5.1GHz) |
| **RAM** | 32GB (4x 8GB) DDR4 ECC |
| **Network** | Onboard 2.5GbE (Intel I225-LM) |
| **Boot Pool** | 2x 128GB SATA SSD (mirrored) |
| **Cache** | 1x 256GB M.2 NVMe (L2ARC) |
| **Storage Pool** | 3x 4TB SATA HDD (RAIDZ1, ~8TB usable) |
| **HBA** | LSI 9300-8i (installed, not in use) |
| **OS** | TrueNAS SCALE 25.10.1 "Goldeye" |

## Hardware Details

### CPU: Intel Xeon W-1370
- **Cores/Threads:** 8C/16T
- **Base Clock:** 2.9 GHz
- **Boost Clock:** Up to 5.1 GHz
- **TDP:** 80W
- **iGPU:** Intel UHD Graphics P750 (32 EUs)
  - Used for Jellyfin hardware transcoding (QuickSync)
  - Supports H.264, HEVC (H.265), VP9 hardware encoding/decoding
- **ECC Support:** Yes (critical for ZFS data integrity)

**Performance Notes:**
- More than adequate for TrueNAS + 20+ Docker containers
- QuickSync dramatically reduces Jellyfin CPU usage during transcoding
- Plenty of headroom for future services

### Motherboard: ASRock W480 Creator
- **Chipset:** Intel W480
- **Form Factor:** ATX
- **PCIe Slots:**
  - 2x PCIe 3.0 x16
  - 1x PCIe 3.0 x4
- **M.2 Slots:** 2x M.2 (NVMe + SATA support)
- **SATA Ports:** 8x SATA 6Gb/s
- **Network:** Intel I225-LM 2.5GbE
- **USB:** Multiple USB 3.2 Gen2 ports

**Why This Board:**
- Native ECC memory support
- Ample SATA ports for storage expansion
- PCIe slots available for HBA and future expansion
- Intel 2.5GbE provides good network performance

### Network: Onboard 2.5GbE
- **Controller:** Intel I225-LM
- **Speed:** 2.5 Gigabit Ethernet
- **Notes:**
  - Connected to YuanLey switch
  - Sufficient for current homelab needs
  - Could add second NIC for storage VLAN separation in future

**Future Network Expansion:**
- Option to add PCIe 10GbE NIC when upgrading switch
- Could use second PCIe slot for dedicated storage network

### Storage Architecture

#### Boot Pool (TrueNAS OS)
- **Config:** 2x 128GB SATA SSD in mirror
- **Purpose:** TrueNAS SCALE operating system and configuration
- **Redundancy:** Mirror provides protection against single drive failure
- **Usage:** ~20-30GB typically (plenty of headroom)

**Why Mirrored SSDs:**
- Fast boot times
- OS/config redundancy
- Separate from data pool (good practice)

#### L2ARC Cache
- **Drive:** 1x 256GB M.2 NVMe
- **Purpose:** ZFS L2ARC (Level 2 Adaptive Replacement Cache)
- **Benefit:** Speeds up repeated reads of frequently accessed data
- **Use Case:** Helpful for Jellyfin metadata, Immich thumbnails

**L2ARC Notes:**
- Not essential but improves performance for read-heavy workloads
- Would survive removal without data loss
- Could be repurposed as SLOG (ZFS Intent Log) if write performance needed

#### Data Pool: "tank"
- **Config:** 3x 4TB SATA HDD in RAIDZ1
- **Usable Capacity:** ~8TB
- **Current Usage:** ~6TB (75% full)
- **Redundancy:** Single drive failure tolerance
- **Performance:** Sequential reads ~300-400 MB/s

**ZFS Pool Layout:**
```
tank (RAIDZ1)
├── 4TB HDD #1
├── 4TB HDD #2
└── 4TB HDD #3

Datasets:
├── /tank/configs (Docker configs and compose files)
├── /tank/media (1.22TB - Jellyfin library + downloads)
│   ├── /downloads (qBittorrent destination)
│   ├── /movies
│   ├── /tv
│   └── /music
├── /tank/photos (250GB - Immich photo storage)
└── /tank/stacks (Dockge compose files)
```

**Expansion Plans:**
- LSI 9300-8i HBA available for switching to SAS drives
- Could add drives to expand pool (not recommended with RAIDZ1)
- Better option: Add new RAIDZ2 vdev when capacity needed
- Target: 6-8x larger SAS drives in RAIDZ2 for better redundancy

### LSI 9300-8i HBA
- **Status:** Installed but not currently in use
- **Interface:** PCIe 3.0 x8
- **Ports:** 8x internal SAS/SATA
- **Mode:** IT mode (no RAID, pass-through for ZFS)
- **Future Use:** Planned for SAS drive migration

**Why HBA:**
- Direct disk access for ZFS (no hardware RAID layer)
- Support for SAS enterprise drives
- Better performance than motherboard SATA

## Network Configuration

**Current Setup:**
- Single 2.5GbE connection to switch
- IP: 192.168.1.X (DHCP from Deco, should set static)
- No VLANs configured

**Future Plans:**
- Static IP on management VLAN (VLAN 10)
- Potentially add second NIC for storage VLAN (VLAN 20)
- Configure jumbo frames (MTU 9000) for storage traffic

## Power & Cooling

**Power:**
- Estimated consumption: 60-80W idle, 120-150W under load
- Running 24/7
- No UPS currently (should add for clean shutdowns)

**Cooling:**
- Stock CPU cooler
- Case fans (standard ATX case)
- Runs cool under normal Docker load
- HDDs run at acceptable temperatures

**Future Considerations:**
- Add UPS for graceful shutdown during power outages
- Monitor HDD temperatures as pool fills

## Performance Characteristics

### Strengths
- **CPU:** Plenty of power for containers + future VMs
- **iGPU:** Excellent for hardware transcoding
- **RAM:** 32GB sufficient for ZFS ARC + containers
- **Network:** 2.5GbE adequate for current usage

### Limitations
- **Storage:** Only single-parity RAIDZ1 (vulnerable during rebuilds)
- **Network:** Single NIC (no redundancy, no VLAN segregation)
- **Expansion:** SATA drives limit future pool growth

### Bottlenecks (Current)
- None identified under current load
- Network saturates at 2.5Gbps during large file transfers
- Storage IOPS fine for current services

## Upgrade Path

### Near-Term (Next 6 months)
1. **Set static IP** instead of DHCP
2. **Configure automated snapshots** (critical before major changes)
3. **Add UPS** for clean shutdowns
4. **Monitor pool capacity** - approaching 80% full

### Medium-Term (6-12 months)
1. **Add second NIC** for storage VLAN
2. **Migrate to SAS drives** using HBA
3. **Expand to RAIDZ2** for better redundancy
4. **Consider RAM upgrade** to 64GB if running VMs on TrueNAS

### Long-Term (1-2 years)
1. **10GbE network card** if upgrading backbone
2. **Larger pool expansion** (possibly 40-60TB usable)
3. **Offload more services to Proxmox** to reduce TrueNAS load

## Maintenance Schedule

**Weekly:**
- Check dashboard for alerts
- Review pool status and SMART data

**Monthly:**
- Verify snapshots are running
- Check dataset usage and growth trends
- Review container logs for issues

**Quarterly:**
- Test snapshot restore procedure
- Review and update Docker containers
- Check for TrueNAS SCALE updates

**Annually:**
- SMART extended test on all drives
- Review and refresh documentation
- Evaluate hardware upgrade needs

---

*Last Updated: 2025-01-26*