# TrueNAS Server Hardware

## Specifications

| Component | Details |
|-----------|---------|
| **Motherboard** | ASRock W480 Creator |
| **CPU** | Intel Xeon W-1370 (8C/16T, Base 2.9GHz, Boost 5.1GHz) |
| **RAM** | 32GB DDR4 (non-ECC — verified via `system.info`/EDAC, no ECC module detected despite board supporting it) |
| **Network** | Onboard 2.5GbE (Intel I225-LM) |
| **GPU (discrete)** | NVIDIA RTX 3060 12GB (Gigabyte WINDFORCE, GA106) — installed, driver loaded, allocated to Ollama |
| **PSU** | EVGA SuperNOVA 850 GA (80+ Gold, fully modular) |
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
  - Hardware encode + decode: H.264, HEVC (H.265) 8-bit and 10-bit
  - Decode only: VP9, AV1 (AV1 *encode* needs Intel Arc or RTX 40-series — not available on Rocket Lake)
- **ECC Support:** Board/CPU support ECC, but the installed RAM is non-ECC (confirmed live — not a config assumption). ZFS still works fine without ECC; it just loses the extra in-memory bit-error protection ECC would add on top of ZFS's own checksumming.

**Performance Notes:**
- More than adequate for TrueNAS + 20+ Docker containers
- QuickSync dramatically reduces Jellyfin CPU usage during transcoding
- Plenty of headroom for future services

### Discrete GPU: NVIDIA RTX 3060 12GB

Added to give the box local AI acceleration. Purchased used (~$225).

| Property | Value |
|----------|-------|
| **Model** | Gigabyte GV-N3060GAMING OC-12GD (triple-fan WINDFORCE) |
| **Silicon** | GA106 "Lite Hash Rate", Ampere |
| **VRAM** | 12GB GDDR6, 360 GB/s |
| **Power** | 170W, single 8-pin PCIe |
| **Card length** | 282mm (11.1") |
| **Slot** | PCIe 3.0 x16 (second x16 slot; LSI 9300-8i occupies the first) |
| **Driver** | NVIDIA 570.172.08 (verified via `nvidia-smi`) |

**Verify the card is present and the driver is loaded:**

```bash
# Should report the card, VRAM total, and driver version
nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv

# Both GPUs should appear: Intel iGPU at 00:02.0, NVIDIA at 01:00.0
lspci | grep -iE "vga|3d"
```

#### iGPU / dGPU split (deliberate)

The two GPUs are assigned to different duties rather than pooled:

| GPU | Assigned workload | Why |
|-----|-------------------|-----|
| Intel UHD P750 (iGPU) | Jellyfin transcoding | QuickSync is efficient for video; keeps NVENC session limits out of play |
| RTX 3060 (dGPU) | Ollama, Immich ML, occasional vLLM | Keeps video transcoding off the AI card so a Jellyfin stream can't stall an inference job |

Containers *can* share a single GPU because TrueNAS 25.10 runs Docker rather than
k3s. VM passthrough was avoided deliberately — it would bind the card exclusively
to one guest and take it away from every container on the host.

#### Granting GPU access

Neither TrueNAS Apps nor Dockge containers get GPU access by default; each needs it
granted explicitly:

- **TrueNAS Apps** — edit the app → *Resources / GPU Configuration* → allocate the NVIDIA device. Already done for Ollama.
- **Dockge / compose stacks** — declare the device reservation in the compose file:

```yaml
services:
  ollama:
    image: ollama/ollama:latest
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
```

**Always verify after wiring it up** — a container denied GPU access falls back to
CPU silently, which presents only as "the model is slow":

```bash
# A GPU-backed workload should appear here holding VRAM
nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv
```

**Check this while a model is actually loaded.** Ollama unloads models after its
`keep_alive` timeout (5 minutes by default), so an idle-but-perfectly-healthy
Ollama reports **0 MiB VRAM and no compute processes**. Zero VRAM at idle is normal
and is not evidence of a CPU fallback — a trap already fallen into once here.

#### VRAM sizing for local models

12GB is the constraint that decides model choice. The model *plus its KV cache*
must fit in VRAM; once it spills to system RAM, throughput collapses.

| Model size | Quantized footprint (Q4_K_M) | Verdict |
|------------|------------------------------|---------|
| 7–9B | ~5–6GB | Comfortable, with room for long context |
| 12–14B | ~8–9GB | Fits, but context headroom gets tight |
| 27B+ | >16GB | Does not fit — will spill and crawl |

#### PSU cable gotcha (cost a few days)

The EVGA SuperNOVA 850 GA is fully modular, and **modular cable pinouts are
specific to the PSU model** — a cable from another unit can be physically
identical and electrically wrong. This card needed an EVGA GA-certified PCIe
cable (P/N `W001-00-000147`); the install waited on sourcing it. Never reuse
modular cables across PSU models.

### Motherboard: ASRock W480 Creator
- **Chipset:** Intel W480
- **Form Factor:** ATX
- **PCIe Slots:**
  - 2x PCIe 3.0 x16 — **both now occupied** (LSI 9300-8i HBA + RTX 3060)
  - 1x PCIe 3.0 x4 — free (candidate for a SAS expander or a 10GbE NIC, but not both)
- **M.2 Slots:** 2x M.2 (NVMe + SATA support)
- **SATA Ports:** 8x SATA 6Gb/s
- **Network:** Intel I225-LM 2.5GbE
- **USB:** Multiple USB 3.2 Gen2 ports

**Why This Board:**
- Native ECC memory support (board supports it; current installed RAM is non-ECC — see CPU section above. Swapping to ECC modules would be a straightforward future upgrade if desired)
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
- Estimated consumption: 60-80W idle, 120-150W under load (pre-GPU baseline)
- The RTX 3060 adds up to 170W under inference load; idle draw for the card is
  roughly 10-15W. Budget ~320W peak for the system with the GPU working.
- PSU is 850W, so there is ample headroom today — but see the spin-up note below
  if the pool ever expands to a large drive count
- Running 24/7
- No UPS currently (should add for clean shutdowns)

**Drive spin-up surge (relevant only if the pool grows):**
Spinning disks draw far more at spin-up than at idle — roughly 25-30W each for a
few seconds versus ~5-8W steady. With only 3 drives this is a non-issue. A move
to a 20-bay chassis would put the simultaneous surge near 600W, which stacks on
top of the GPU and CPU load against an 850W PSU. Staggered spin-up (via HBA or
backplane) becomes mandatory at that scale, not optional.

**Cooling:**
- Stock CPU cooler
- Case fans (standard ATX case)
- Runs cool under normal Docker load
- HDDs run at acceptable temperatures
- RTX 3060 idles around 55°C in this case. The WINDFORCE is an open-air cooler,
  so it dumps heat *into* the chassis rather than exhausting it out the bracket —
  case airflow is doing the GPU's exhaust work. Worth re-checking under sustained
  inference load, which has not been tested yet.

**Future Considerations:**
- Add UPS for graceful shutdown during power outages
- Monitor HDD temperatures as pool fills
- Measure GPU temps under a sustained inference run before trusting the current
  cooling setup for long jobs

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

*Last Updated: 2026-08-16*