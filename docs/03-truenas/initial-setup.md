# TrueNAS Initial Setup and Dataset Configuration

## Overview

This document covers the initial setup and dataset organization for your TrueNAS SCALE server. While your system is already running, this serves as reference documentation and guidance for future changes.

## Current System Overview

**Hardware:**
- Motherboard: ASRock W480 Creator
- CPU: Intel Xeon W-1370 (8C/16T)
- RAM: 32GB DDR4 ECC
- Network: Onboard 2.5GbE (Intel I225-LM)
- Storage: 3x 4TB SATA HDD (RAIDZ1) + cache/boot drives

**Software:**
- OS: TrueNAS SCALE 25.10.1 "Goldeye"
- Pool: tank (RAIDZ1, ~8TB usable)
- Current Usage: ~6TB (75% full)

## Storage Pool Architecture

### Current Pool Configuration

**Pool Name:** tank

**Configuration:** RAIDZ1 (3 drives)
- Single parity drive (can lose 1 drive)
- ~8TB usable capacity from 12TB raw
- Good balance of capacity and redundancy for homelab

**Vdevs:**
```
tank (pool)
└── RAIDZ1 vdev
    ├── 4TB HDD #1
    ├── 4TB HDD #2
    └── 4TB HDD #3
```

**Additional Components:**
- **Boot Pool:** 2x 128GB SATA SSD (mirrored) - TrueNAS OS
- **L2ARC Cache:** 256GB M.2 NVMe - Read cache

### Understanding RAIDZ1

**Redundancy:**
- Can survive single drive failure
- No data loss if 1 drive fails
- **Warning:** Vulnerable during rebuild (if 2nd drive fails during resilver, data is lost)

**Capacity:**
- RAIDZ1 with 3 drives: 2/3 of raw capacity (~67%)
- Your pool: 12TB raw → ~8TB usable

**Performance:**
- Read: Distributed across all drives (faster)
- Write: Slower than mirror due to parity calculation
- Sequential read: ~300-400 MB/s (good for media streaming)

**When to Upgrade:**
- Consider RAIDZ2 (2 parity drives) when adding more drives
- RAIDZ2 with 6+ drives provides better protection
- Can't convert RAIDZ1 → RAIDZ2 in-place (would need migration)

## Dataset Structure

### Current Datasets

```
/mnt/tank/
├── configs/          # Docker container configurations
├── media/            # Jellyfin media library (1.22TB)
│   ├── downloads/    # qBittorrent download location
│   ├── movies/       # Organized movies
│   ├── tv/           # Organized TV shows
│   └── music/        # Music library
├── photos/           # Immich photo storage (250GB)
└── stacks/           # Dockge Docker Compose files
```

### Planned Additions

```
/mnt/tank/
├── [existing datasets above]
├── proxmox/          # Proxmox integration (to be created)
│   ├── backups/      # VM/container backups
│   ├── isos/         # Installation ISOs
│   └── templates/    # VM templates
└── kubernetes/       # k3s persistent storage (to be created)
    └── pvs/          # Persistent volumes
```

## Creating Datasets

### Why Use Datasets?

Datasets are like folders but with ZFS superpowers:
- Independent mount points
- Separate compression settings
- Independent snapshots
- Quota management
- Inheritance of properties

**Use datasets for:**
- Logical separation (photos, media, backups)
- Different snapshot schedules
- Different compression settings
- Quota enforcement

**Use directories for:**
- Simple organization within dataset
- No need for separate snapshots
- No special properties needed

### Creating Datasets via Web UI

**Navigate to:** Storage → Pools → tank

#### Example: Create Proxmox Dataset

1. Click "Add Dataset"
2. **Name:** proxmox
3. **Sync:** Standard (default)
4. **Compression:** LZ4 (recommended, enabled by default)
5. **Enable Atime:** Off (better performance)
6. **Quota:** None (or set limit if desired)
7. **Reservation:** None
8. **Record Size:** 128K (default, good for general use)
9. **Case Sensitivity:** Sensitive (default)
10. Click "Save"

**Create Subdatasets:**
1. Select `/tank/proxmox` dataset
2. Click "Add Dataset"
3. **Name:** backups
4. Configure as needed
5. Repeat for `isos` and `templates`

#### Example: Create Kubernetes Dataset

1. Navigate to `/tank`
2. Click "Add Dataset"
3. **Name:** kubernetes
4. **Compression:** LZ4
5. **Enable Atime:** Off
6. Click "Save"

**Create subdataset for persistent volumes:**
1. Select `/tank/kubernetes`
2. Click "Add Dataset"
3. **Name:** pvs
4. Click "Save"

### Creating Datasets via CLI

**SSH to TrueNAS:**
```bash
ssh admin@192.168.1.X
```

**Create dataset:**
```bash
# Create main dataset
zfs create tank/proxmox

# Create subdatasets
zfs create tank/proxmox/backups
zfs create tank/proxmox/isos
zfs create tank/proxmox/templates

# Create Kubernetes datasets
zfs create tank/kubernetes
zfs create tank/kubernetes/pvs
```

**Set properties:**
```bash
# Disable atime (better performance)
zfs set atime=off tank/proxmox

# Set compression (usually already enabled)
zfs set compression=lz4 tank/proxmox

# Set quota (optional)
zfs set quota=500G tank/proxmox/backups

# Set reservation (optional, guarantees space)
zfs set reservation=100G tank/photos
```

**Verify:**
```bash
# List datasets
zfs list

# Show properties
zfs get all tank/proxmox

# Show specific property
zfs get compression tank/proxmox
```

## Dataset Properties Explained

### Compression

**Options:**
- `off` - No compression
- `lz4` - Fast compression (recommended, ~2:1 ratio for text, minimal CPU)
- `gzip-1` to `gzip-9` - Slower, better compression
- `zstd` - Modern, balanced (available in newer ZFS)

**Recommendation:** Use `lz4` for everything (enabled by default)

**Check compression effectiveness:**
```bash
zfs get compressratio tank/media
# Shows actual compression achieved
```

### Atime (Access Time)

**What it does:** Updates timestamp every time file is read

**Recommendation:** Disable (`atime=off`)
- Reduces write operations
- Better performance (especially for media libraries)
- Rarely needed in homelab

### Sync

**Options:**
- `standard` - Write to ZIL (ZFS Intent Log), then flush to disk
- `always` - Synchronous writes (slower, safer)
- `disabled` - Write cache only (faster, dangerous)

**Recommendation:** Use `standard` (default)

### Record Size

**Default:** 128K

**Adjust for specific workloads:**
- Database (PostgreSQL): 8K or 16K
- Large files (videos): 1M
- General use: 128K (don't change unless you know why)

**Set at dataset creation, cannot change later without recreating**

### Quotas and Reservations

**Quota:** Maximum space dataset can use
```bash
zfs set quota=100G tank/photos
```

**Reservation:** Guaranteed space for dataset
```bash
zfs set reservation=50G tank/photos
```

**Useful for:**
- Preventing one dataset from filling pool
- Guaranteeing space for critical data (photos, configs)

## Sharing Datasets

### NFS Shares (For Proxmox, k3s)

**Create NFS Share:**

1. **Shares → Unix (NFS) Shares → Add**
2. **Path:** Browse to dataset (e.g., `/mnt/tank/proxmox/backups`)
3. **Description:** "Proxmox VM Backups"
4. **Network:**
   - Current: `192.168.1.0/24`
   - Future: `192.168.30.0/24` (Services VLAN) or `192.168.20.0/24` (Storage VLAN)
5. **Maproot User:** root
6. **Maproot Group:** root
7. **Security:** `sys` (default, Kerberos not needed for homelab)
8. Click "Save"

**Enable NFS Service:**
- System Settings → Services → NFS → Enable
- Check "Start Automatically"

**Test from Linux:**
```bash
# Mount test
sudo mount -t nfs 192.168.1.10:/mnt/tank/proxmox/backups /mnt/test

# Check
ls -la /mnt/test

# Unmount
sudo umount /mnt/test
```

### SMB Shares (For Windows/Mac)

**Create SMB Share:**

1. **Shares → Windows (SMB) Shares → Add**
2. **Path:** Browse to dataset (e.g., `/mnt/tank/photos`)
3. **Name:** photos
4. **Purpose:** Default share parameters
5. **Description:** "Photo Storage"
6. **Enable:** Check
7. Click "Save"

**Configure ACL (Permissions):**
1. Storage → Pools → tank → photos → Edit Permissions
2. **Owner:** Your username
3. **Group:** Your group
4. **Permissions:** As needed (typically 755 or 770)
5. **Apply permissions recursively:** Check
6. Click "Save"

**Enable SMB Service:**
- System Settings → Services → SMB → Enable
- Check "Start Automatically"

**Access from Windows:**
```
\\192.168.1.10\photos
```

**Access from Mac:**
```
smb://192.168.1.10/photos
```

### iSCSI (For Proxmox VM Storage)

**More complex, used for block-level storage (VMs)**

**Create iSCSI Extent:**
1. Shares → Block (iSCSI) Shares → Extents → Add
2. **Name:** proxmox-vms
3. **Extent Type:** File
4. **Path:** `/mnt/tank/proxmox/vms/extent.img` (create file)
5. **Extent Size:** 500 GiB (adjust as needed)
6. Click "Save"

**Create Target:**
1. Shares → Block (iSCSI) → Targets → Add
2. **Target Name:** proxmox-target
3. **Target Alias:** Proxmox VMs
4. Click "Save"

**Associate Target with Extent:**
1. Shares → Block (iSCSI) → Associated Targets → Add
2. **Target:** proxmox-target
3. **LUN ID:** 0
4. **Extent:** proxmox-vms
5. Click "Save"

**Enable iSCSI Service:**
- System Settings → Services → iSCSI → Enable

**Configure in Proxmox:**
- Datacenter → Storage → Add → iSCSI
- Provide TrueNAS IP and target name

**Recommendation:** Use NFS for most things, iSCSI only if you need better performance for specific VMs.

## Dataset Maintenance

### Monitoring Usage

**Web UI:**
Storage → Pools → tank → View datasets with usage

**CLI:**
```bash
# List datasets with used space
zfs list

# Show detailed space breakdown
zfs list -o space tank/media

# Human-readable
zfs list -o name,used,avail,refer,mountpoint

# Show compression ratio
zfs get compressratio tank/media
```

### Checking Pool Health

**Web UI:**
Storage → Pools → tank → Status

**CLI:**
```bash
# Pool status
zpool status tank

# Show errors (should be 0)
zpool status -v

# Check individual disk SMART data
smartctl -a /dev/sda
```

### Scrub (Data Integrity Check)

**What is Scrub?**
- Reads all data and verifies checksums
- Detects silent corruption
- Repairs errors if redundancy available (RAIDZ1 can fix single-bit errors)

**Schedule Scrub:**
1. Storage → Pools → tank → Scrub Tasks → Add
2. **Frequency:** Monthly (recommended)
3. **Day of Month:** 1 (first day of month)
4. **Hour:** 02:00 (low activity time)
5. Click "Save"

**Manual Scrub:**
```bash
# Start scrub
zpool scrub tank

# Check progress
zpool status tank

# Stop scrub (if needed)
zpool scrub -s tank
```

**How long does scrub take?**
- Depends on pool size and disk speed
- Your 8TB pool: ~8-12 hours
- Runs in background, doesn't stop normal operations

### TRIM (SSD Maintenance)

**For cache and boot SSDs:**

**Enable auto-TRIM:**
```bash
# Check TRIM support
zpool get autotrim tank-boot

# Enable TRIM (boot pool)
zpool set autotrim=on tank-boot
```

**Manual TRIM:**
```bash
zpool trim tank-boot
```

## Expanding Storage

### Adding Drives to Existing Pool

**RAIDZ1 Limitation:** Cannot add single drive to existing RAIDZ1 vdev

**Options:**
1. **Add new RAIDZ1 vdev** (requires 3+ more drives)
2. **Add mirror vdev** (requires 2 drives, different redundancy in same pool)
3. **Replace drives with larger** (replace all 3, one at a time)

**Option 1: Add new RAIDZ1 vdev (Recommended for expansion)**

Requirements: 3+ additional drives

```bash
# Add new vdev to pool
zpool add tank raidz1 /dev/sdd /dev/sde /dev/sdf

# Result: pool has 2 vdevs, ~16TB total
```

**Benefits:**
- Doubles capacity
- Better performance (striped across vdevs)

**Drawback:**
- If either vdev fails completely, entire pool is lost
- Still only single parity per vdev

**Option 3: Replace with larger drives (Gradual upgrade)**

Replace one drive at a time with larger drive:

```bash
# Replace drive (resilver starts automatically)
zpool replace tank /dev/sda /dev/sdg

# Wait for resilver to complete (hours)
zpool status tank

# Repeat for other 2 drives

# After all 3 replaced, expand pool
zpool online -e tank /dev/sdg /dev/sdh /dev/sdi
```

**Example:** Replace 3x 4TB with 3x 8TB → pool becomes ~16TB

**Benefits:**
- Gradual, less risk
- No additional slots needed

**Drawback:**
- Must replace all 3 to see capacity increase
- Extended period with degraded redundancy

### Migrating to RAIDZ2 (Better Redundancy)

**Cannot convert RAIDZ1 → RAIDZ2 in-place**

**Process:**
1. Add new RAIDZ2 vdev (6+ drives)
2. Copy data from RAIDZ1 vdev to RAIDZ2 vdev
3. Remove RAIDZ1 vdev (risky, backup first!)
4. Or keep both (mixed redundancy, not recommended)

**Future Planning:**
- When capacity needs grow, consider building new pool as RAIDZ2
- 6-8 drives in RAIDZ2 (better protection, good capacity)

## Best Practices

1. **Pool Usage < 80%**
   - ZFS performance degrades above 80% full
   - Plan expansion when reaching 70-75%

2. **Regular Scrubs**
   - Monthly scrubs detect corruption early
   - Schedule during low-usage times

3. **Monitor SMART Data**
   - Check drive health regularly
   - Replace drives showing errors immediately

4. **Snapshots Before Changes**
   - Always snapshot before major changes
   - Easy rollback if something breaks

5. **Offsite Backups**
   - Snapshots are NOT backups (same hardware)
   - Replicate to external drive or cloud
   - 3-2-1 rule: 3 copies, 2 media types, 1 offsite

6. **UPS for Power Protection**
   - Unclean shutdowns can corrupt data
   - UPS allows graceful shutdown

7. **ECC RAM**
   - You have ECC (good!)
   - Critical for ZFS data integrity
   - Protects against memory corruption

8. **Keep Firmware Updated**
   - Regular TrueNAS updates
   - Disk firmware updates
   - HBA/controller firmware

9. **Document Everything**
   - Keep this documentation updated
   - Note any changes to pool/datasets
   - Record drive serial numbers

10. **Test Restores**
    - Regularly test snapshot rollback
    - Verify backups are usable
    - Practice disaster recovery

## Troubleshooting

### Pool Degraded (Drive Failure)

**Symptoms:**
- Email alert or dashboard warning
- `zpool status` shows DEGRADED

**Action:**
```bash
# Check status
zpool status tank

# Identify failed drive (shows UNAVAIL or FAULTED)

# Order replacement drive (same size or larger)

# Replace drive
zpool replace tank /dev/sda /dev/sdg

# Monitor resilver
zpool status tank
# Can take hours depending on data amount
```

### Pool Running Out of Space

**Short-term:**
- Delete old snapshots
- Remove unused files
- Enable compression if not already

**Long-term:**
- Plan storage expansion
- Archive old data to external storage

### Slow Performance

**Check:**
- Pool fragmentation: `zpool list -v` (>30% fragmentation hurts performance)
- Pool usage: Keep below 80%
- ARC hit rate: `arc_summary` (should be >80%)

**Solutions:**
- Add more RAM (helps ARC caching)
- Add SSD cache (L2ARC) - you already have
- Upgrade to faster drives
- Add more vdevs (increases IOPS)

### Cannot Delete Dataset

**Error:** "Dataset is busy"

**Cause:** Dataset mounted or shared

**Solution:**
1. Stop services using dataset
2. Unmount: `zfs unmount tank/old-dataset`
3. Remove shares (SMB/NFS)
4. Delete: `zfs destroy tank/old-dataset`

## Next Steps

1. Create Proxmox datasets (`/tank/proxmox/*`)
2. Create Kubernetes dataset (`/tank/kubernetes/pvs`)
3. Set up NFS shares for Proxmox
4. Configure automated snapshots (see [snapshots-backup.md](snapshots-backup.md))
5. Set up monthly scrub task
6. Monitor pool health regularly
7. Plan for storage expansion (when >70% full)

---

*Last Updated: 2025-01-26*