# TrueNAS Snapshots and Backup Configuration

## Overview

Snapshots and backups are critical for protecting data in your homelab. This guide covers:
- ZFS snapshots for instant recovery
- Automated snapshot scheduling
- Replication for offsite/backup storage
- Best practices for data protection

**Why This Matters:**
- 80,000 photos in Immich
- 1.22TB media library in Jellyfin
- All service configurations in `/tank/configs`
- Before any major changes (migrations, updates)

## ZFS Snapshots Explained

### What Are Snapshots?
- Point-in-time copy of dataset
- Copy-on-write: Only changed data uses space
- Nearly instant to create (milliseconds)
- Can be taken while dataset is in use
- Essential for data protection

### How Snapshots Work
1. **Snapshot created:** Records current state
2. **Data modified:** New data written, old data preserved in snapshot
3. **Space usage:** Only delta (changes) consumes additional space
4. **Rollback:** Restore dataset to snapshot state

### Example
```
Dataset: /tank/photos (100GB used)
Snapshot: tank/photos@2025-01-26_00:00
  - Takes seconds to create
  - Uses 0GB initially (no changes yet)
  - After 1 week: Uses 5GB (5GB of photos changed/added)
  - Can rollback to exactly how it was on 2025-01-26
```

### Snapshot Limitations
- **Not a backup:** Snapshots are on same physical disks
- **Disk failure:** If pool fails, snapshots are lost too
- **Accidental deletion:** Can protect against file deletion, not hardware failure
- **Solution:** Replicate snapshots to second location (external drive, cloud, another NAS)

## Automated Snapshot Tasks

### Planning Snapshot Schedule

**Recommended Strategy:**
- **Frequent:** Hourly for critical, changing data
- **Daily:** Most datasets
- **Weekly:** Long-term history
- **Retention:** Balance recovery needs vs. disk space

**Example Schedule for Your Homelab:**

| Dataset | Frequency | Retention | Reason |
|---------|-----------|-----------|--------|
| /tank/photos | Hourly | Keep 48 hours | Immich uploads photos frequently |
| /tank/photos | Daily | Keep 30 days | Long-term recovery |
| /tank/media | Daily | Keep 7 days | Media doesn't change often |
| /tank/configs | Hourly | Keep 48 hours | Before config changes |
| /tank/configs | Daily | Keep 60 days | Long history for configs |
| /tank/stacks | Daily | Keep 30 days | Docker compose changes |

### Creating Snapshot Tasks (Web UI)

**Navigate to:**
Data Protection → Periodic Snapshot Tasks

#### Hourly Snapshots for Photos

**Create Task:**
1. Click "Add" (top-right)
2. **Dataset:** tank/photos
3. **Recursive:** No (unless subdatasets need snapshots)
4. **Snapshot Lifetime:** 2 days (48 hours)
5. **Naming Schema:** auto-%Y-%m-%d_%H-%M (e.g., auto-2025-01-26_14-00)
6. **Schedule:**
   - Preset: Hourly
   - Or Custom: Every hour (0 * * * *)
7. **Begin:** 00:00 (start at midnight)
8. **End:** 23:59 (run all day)
9. **Enabled:** Check
10. Click "Save"

#### Daily Snapshots for Photos (Long-term)

**Create Task:**
1. Click "Add"
2. **Dataset:** tank/photos
3. **Recursive:** No
4. **Snapshot Lifetime:** 30 days
5. **Naming Schema:** daily-%Y-%m-%d
6. **Schedule:**
   - Preset: Daily
   - Time: 02:00 (2 AM, low activity time)
7. **Enabled:** Check
8. Click "Save"

#### Daily Snapshots for Media

**Create Task:**
1. **Dataset:** tank/media
2. **Recursive:** No
3. **Snapshot Lifetime:** 7 days
4. **Naming Schema:** daily-%Y-%m-%d
5. **Schedule:** Daily at 03:00 (after photos)
6. **Enabled:** Check
7. Click "Save"

#### Hourly + Daily Snapshots for Configs

**Hourly Task:**
1. **Dataset:** tank/configs
2. **Lifetime:** 2 days
3. **Naming Schema:** auto-%Y-%m-%d_%H-%M
4. **Schedule:** Hourly
5. **Enabled:** Check

**Daily Task:**
1. **Dataset:** tank/configs
2. **Lifetime:** 60 days
3. **Naming Schema:** daily-%Y-%m-%d
4. **Schedule:** Daily at 01:00
5. **Enabled:** Check

#### Daily Snapshots for Stacks (Docker Compose)

**Create Task:**
1. **Dataset:** tank/stacks
2. **Lifetime:** 30 days
3. **Naming Schema:** daily-%Y-%m-%d
4. **Schedule:** Daily at 01:30
5. **Enabled:** Check

### Verifying Snapshot Tasks

**Check Tasks:**
Data Protection → Periodic Snapshot Tasks → View tasks

**Check Actual Snapshots:**
Storage → Pools → tank → [select dataset] → Snapshots

Should see snapshots appearing according to schedule.

### Managing Snapshots (CLI)

**List all snapshots:**
```bash
zfs list -t snapshot
```

**List snapshots for specific dataset:**
```bash
zfs list -t snapshot -r tank/photos
```

**Create manual snapshot:**
```bash
zfs snapshot tank/photos@before-migration
```

**Delete snapshot:**
```bash
zfs destroy tank/photos@before-migration
```

**Check snapshot space usage:**
```bash
zfs list -t snapshot -o name,used,refer
```

## Rolling Back to Snapshots

### When to Rollback
- Accidentally deleted files
- Service configuration broke
- Before/after testing (rollback if test fails)
- Ransomware/corruption detected

### Rollback Process (Web UI)

**Warning:** Rollback destroys all data created after snapshot!

1. Navigate to: Storage → Pools → tank → [dataset] → Snapshots
2. Find snapshot to restore (e.g., daily-2025-01-25)
3. Click three-dots menu → Rollback
4. **Confirm:** Warning about data loss
5. Click "Rollback"

**Dataset instantly reverts to snapshot state.**

### Rollback Process (CLI)

```bash
# List available snapshots
zfs list -t snapshot tank/photos

# Rollback to specific snapshot
zfs rollback tank/photos@daily-2025-01-25

# Rollback to most recent snapshot
zfs rollback tank/photos@auto-2025-01-26_14-00
```

**For newer snapshots:**
```bash
# If there are snapshots newer than target, use -r to delete them
zfs rollback -r tank/photos@daily-2025-01-25
```

### Cloning Snapshots (Non-Destructive)

Instead of rolling back, clone snapshot to separate dataset:

```bash
# Clone snapshot to new dataset
zfs clone tank/photos@daily-2025-01-25 tank/photos-restored

# Now both exist:
# tank/photos (current state)
# tank/photos-restored (snapshot state)

# Access via /mnt/tank/photos-restored
# Copy needed files back to tank/photos
```

**Benefit:** Non-destructive, can compare old vs. new.

## File-Level Restore (Without Rollback)

### Accessing Snapshot Data

Snapshots are accessible as read-only hidden directories:

**Location:** `/mnt/tank/[dataset]/.zfs/snapshot/[snapshot-name]`

**Example:**
```bash
# Current data
/mnt/tank/photos/2024/vacation.jpg (deleted by mistake)

# Restore from snapshot
cp /mnt/tank/photos/.zfs/snapshot/daily-2025-01-25/2024/vacation.jpg /mnt/tank/photos/2024/

# File restored!
```

### Via SMB Share (Windows/Mac)

**Windows:**
1. Open `\\192.168.1.X\photos`
2. Navigate to folder where file was
3. Right-click folder → Properties → Previous Versions
4. Windows shows snapshots as "Previous Versions"
5. Browse and restore files

**Mac:**
1. Connect to `smb://192.168.1.X/photos`
2. Time Machine-style interface may work (if enabled)
3. Or access `.zfs/snapshot` manually via Finder

### Via TrueNAS Shell

```bash
# SSH to TrueNAS or use web shell
ssh admin@192.168.1.X

# Navigate to snapshot
cd /mnt/tank/photos/.zfs/snapshot/daily-2025-01-25

# Find file
ls -lh 2024/vacation.jpg

# Copy back
cp 2024/vacation.jpg /mnt/tank/photos/2024/
```

## Replication for Offsite Backup

### Why Replication?
- Snapshots alone are not backups (same hardware)
- Replication copies snapshots to second location
- Protects against hardware failure, theft, disaster

### Replication Targets
**Options:**
1. **External USB Drive:** Simple, cheap, manual
2. **Second TrueNAS/FreeNAS:** Automated, ideal
3. **Cloud (B2, S3):** Offsite, requires internet
4. **Remote TrueNAS at Friend/Family:** Best (offsite + fast)

### Replication to USB Drive (Manual)

**Setup:**
1. Connect USB drive to TrueNAS
2. Storage → Import Disk
3. Format as ZFS (creates new pool, e.g., `backup-usb`)
4. Data Protection → Replication Tasks → Add

**Replication Task:**
1. **Source:** tank/photos
2. **Destination:** backup-usb/photos
3. **Recursive:** Yes (include subdatasets)
4. **Replication Schedule:**
   - Manual (run manually)
   - Or Weekly (automatic if USB always connected)
5. **Snapshot Retention:** Keep 30 days
6. Click "Save"

**Run Task:**
- Data Protection → Replication Tasks → Select task → Run Now

**Benefits:**
- Offsite if you remove USB after backup
- Full snapshot history preserved
- Can restore to TrueNAS if needed

### Replication to Cloud (TrueNAS Cloud Sync)

**Supported Services:**
- Backblaze B2
- Amazon S3 / Glacier
- Google Cloud Storage
- Wasabi
- Any S3-compatible

**Setup (Backblaze B2 Example):**
1. Create Backblaze account
2. Create B2 bucket (e.g., `homelab-backup`)
3. Get Application Key (ID and Secret)

**In TrueNAS:**
1. Data Protection → Cloud Sync Tasks → Add
2. **Credential:**
   - Add new credential
   - Provider: Backblaze B2
   - Account ID and Application Key
3. **Transfer Mode:** Sync (or Copy)
4. **Direction:** Push
5. **Source:** /mnt/tank/photos
6. **Bucket:** homelab-backup
7. **Folder:** photos/
8. **Schedule:** Weekly (adjust for bandwidth)
9. **Enabled:** Check
10. Click "Save"

**Cost Estimate (Backblaze B2):**
- Storage: $6/TB/month
- Downloads: $0.01/GB (restore costs money!)
- Your 250GB photos = ~$1.50/month

**Considerations:**
- Uploading 250GB takes time (hours/days depending on internet)
- Restoring also takes time
- Bandwidth caps (if ISP limits upload)

### Testing Backups

**Critical:** Test restores regularly!

**Test Process:**
1. Pick random snapshot
2. Restore single file or folder
3. Verify data integrity
4. Document process and time taken

**Test Schedule:**
- **Monthly:** Restore single file from snapshot
- **Quarterly:** Restore entire dataset to test location
- **Annually:** Full disaster recovery drill (restore everything)

## Disk Space Management

### Monitoring Snapshot Usage

**Web UI:**
Storage → Pools → tank → [dataset]
- Shows "Used by Snapshots" separately

**CLI:**
```bash
# Show snapshot space usage
zfs list -o space tank/photos

# Detailed breakdown
zfs list -t all -o name,used,refer,usedsnap tank/photos
```

### When Snapshots Use Too Much Space

**Symptoms:**
- Pool nearing 80% full
- Large "Used by Snapshots" value

**Solutions:**

**1. Reduce Retention:**
- Data Protection → Periodic Snapshot Tasks
- Edit task → Reduce "Snapshot Lifetime"
- Deletes old snapshots automatically

**2. Manual Delete:**
```bash
# Delete specific snapshot
zfs destroy tank/photos@daily-2025-01-15

# Delete range of snapshots
zfs destroy tank/photos@daily-2025-01-01%daily-2025-01-15

# Delete all auto snapshots older than 7 days (careful!)
# (Better to adjust task settings)
```

**3. Adjust Snapshot Frequency:**
- Reduce from hourly to daily
- Or reduce from daily to weekly

**Balance:** Recovery needs vs. disk space

## Pre-Migration Snapshot Checklist

Before migrating any service from TrueNAS to Proxmox:

- [ ] Create manual snapshot of all datasets
- [ ] Verify snapshots created successfully
- [ ] Test snapshot restore (single file)
- [ ] Document snapshot names and timestamps
- [ ] Ensure automated snapshots are running
- [ ] Check pool has 20%+ free space
- [ ] Backup critical configs to external location

**Example:**
```bash
# Create pre-migration snapshots
zfs snapshot tank/photos@before-proxmox-migration
zfs snapshot tank/media@before-proxmox-migration
zfs snapshot tank/configs@before-proxmox-migration
zfs snapshot tank/stacks@before-proxmox-migration

# Verify
zfs list -t snapshot | grep before-proxmox-migration

# Keep these snapshots for 30+ days
# Delete manually after migration validated
```

## Snapshot Naming Conventions

**Automated (via Periodic Tasks):**
- `auto-%Y-%m-%d_%H-%M` (hourly: auto-2025-01-26_14-00)
- `daily-%Y-%m-%d` (daily: daily-2025-01-26)
- `weekly-%Y-week-%U` (weekly: weekly-2025-week-04)

**Manual (Important Events):**
- `before-[action]` (e.g., before-proxmox-migration)
- `after-[action]` (e.g., after-jellyfin-update)
- `working-[date]` (e.g., working-2025-01-26 for known-good state)

**Keep consistent naming for easy identification!**

## Monitoring and Alerting

### TrueNAS Alerts

**Configure Alerts:**
System Settings → Alert Settings

**Recommended Alerts:**
- Pool usage > 80%
- Snapshot task failed
- Replication task failed
- Scrub completed with errors

**Alert Destinations:**
- Email
- Slack/Discord (via webhook)
- Custom script

### Monitoring Snapshot Health

**Check Task Status:**
Data Protection → Periodic Snapshot Tasks
- Green check = success
- Red X = failed (investigate!)

**Check Replication Status:**
Data Protection → Replication Tasks
- View last run status
- Check for errors

**Scrub Tasks:**
- Storage → Pools → tank → Scrub
- Schedule: Monthly (automatic check for data corruption)
- View last scrub result

## Disaster Recovery Scenarios

### Scenario 1: Accidental File Deletion

**Problem:** Deleted important photos by mistake

**Solution:**
```bash
# Access snapshot
cd /mnt/tank/photos/.zfs/snapshot/daily-2025-01-26

# Find deleted files
ls -lh [path/to/deleted/photos]

# Copy back to current location
cp -r [path/to/deleted/photos] /mnt/tank/photos/[path]
```

**Time to recover:** Minutes

### Scenario 2: Service Configuration Broke

**Problem:** Edited Docker Compose, service won't start

**Solution:**
```bash
# Rollback configs dataset
zfs rollback tank/configs@auto-2025-01-26_14-00

# Or restore single file
cp /mnt/tank/configs/.zfs/snapshot/auto-2025-01-26_14-00/jellyfin/config.yml /mnt/tank/configs/jellyfin/
```

**Time to recover:** Minutes

### Scenario 3: Disk Failure

**Problem:** One disk in RAIDZ1 array failed

**Solution:**
1. TrueNAS alerts about degraded pool
2. Order replacement disk
3. Replace failed disk
4. Storage → Pools → tank → Status → Replace disk
5. Resilver (rebuild) starts automatically
6. Wait for resilver to complete (hours/days depending on size)
7. Pool returns to healthy state

**Data safe:** RAIDZ1 survives single disk failure

**Snapshots preserved:** Still accessible during and after resilver

### Scenario 4: Total Pool Failure (All Disks Dead)

**Problem:** Lightning strike, fire, catastrophic hardware failure

**Solution (If You Have Replication):**
1. Order new hardware (NAS or disks)
2. Install TrueNAS
3. Import USB backup pool (if using USB)
4. Or pull data from cloud (if using B2/S3)
5. Restore snapshots to new pool

**Time to recover:** Days (depends on hardware delivery and restore speed)

**Data loss:** Only data created after last replication

**Without Replication:** Data is LOST (this is why replication matters!)

## Best Practices

1. **Automate Everything:**
   - Snapshots should be automatic, not manual
   - Set retention to balance recovery and space
   - Trust but verify (check that snapshots are running)

2. **3-2-1 Backup Rule:**
   - **3 copies:** Original + 2 backups
   - **2 different media:** TrueNAS + USB/Cloud
   - **1 offsite:** Cloud or remote location
   - Snapshots alone don't satisfy this!

3. **Test Restores:**
   - Monthly: Single file restore test
   - Quarterly: Full dataset restore test
   - Annually: Disaster recovery drill

4. **Monitor Pool Health:**
   - Keep pool below 80% full (ZFS performance degrades)
   - Run monthly scrubs
   - Replace disks at first sign of issues

5. **Document Everything:**
   - Snapshot schedules in Git
   - Disaster recovery procedures
   - Test results and timings

6. **Retention Strategy:**
   - Hourly: 24-48 hours (short-term recovery)
   - Daily: 7-30 days (medium-term)
   - Weekly: 4-12 weeks (long-term)
   - Delete old snapshots (space management)

7. **Critical Data First:**
   - Prioritize photos (irreplaceable)
   - Prioritize configs (time-saving)
   - Media can be re-downloaded if needed

8. **Before Major Changes:**
   - Always create manual snapshot
   - Name it descriptively (before-[action])
   - Keep for 30+ days after change

9. **Separate Replication from Snapshots:**
   - Snapshots: Local, frequent, short retention
   - Replication: Offsite, less frequent, longer retention

10. **Budget for Backups:**
    - External drives: $100-200
    - Cloud storage: $20-50/year for 250GB
    - Worth it to protect irreplaceable data

## Troubleshooting

### Snapshot Task Not Running

**Check:**
1. Task enabled? (Data Protection → Periodic Snapshot Tasks)
2. Schedule correct? (cron format)
3. Check logs: System Settings → Advanced → Log
4. Disk space available?

### Too Many Snapshots

**Problem:** Hundreds of snapshots, running out of space

**Solution:**
1. Adjust retention in snapshot tasks
2. Wait for old snapshots to be cleaned up automatically
3. Or manually delete old snapshots:
```bash
# Delete all auto snapshots older than 2 days
zfs list -t snapshot | grep "auto-2025-01-2[0-4]" | awk '{print $1}' | xargs -n1 zfs destroy
```

### Can't Find Snapshot

**Check:**
1. Naming matches task naming schema
2. Task actually ran (check task history)
3. Snapshot not deleted by retention policy
4. Looking at correct dataset (not subdataset)

### Replication Task Failed

**Check:**
1. Destination storage accessible (USB plugged in, network reachable)
2. Credentials correct (for cloud sync)
3. Enough space on destination
4. Network bandwidth sufficient
5. Check task error message for details

## Next Steps

1. Create automated snapshot tasks for all datasets
2. Verify tasks run successfully (check tomorrow)
3. Test file-level restore from snapshot
4. Plan replication strategy (USB, cloud, or both)
5. Set up replication task
6. Test disaster recovery scenario (restore from replication)
7. Document all snapshot schedules in Git

---

*Last Updated: 2025-01-26*