# ADR-0006: Proxmox Backup Target and Method

**Date:** 2026-09-03

**Status:** Accepted

### Context

The Proxmox cluster ran for roughly six months with **no backups of any kind**. An audit confirmed: no `/etc/pve/jobs.cfg`, no `vzdump` cron entry, an empty dump directory, and no replication jobs. Both live guests — a Docker host VM and an Actual Budget LXC — were entirely uncovered.

This was not theoretical risk. The Actual Budget LXC had already lost its `account.sqlite` to a zero-byte corruption once (2026-07-24) and was recovered only by a password reset, with the wreckage still on disk. A second such event, or any node-local storage failure, would have been unrecoverable — all guest disks live on node-local LVM-thin with no redundancy (see [Proxmox Cluster Hardware](../docs/02-hardware/proxmox-node.md)).

The trigger for finally addressing it: a BIOS flash was planned on `pve-01`, the node hosting every guest in the cluster. A failed firmware write bricks the board, and with no backups that would have taken both workloads with it.

Two questions needed answering: **where** backups go, and **how** they are taken.

### Decision

**Target: TrueNAS over NFS**, not a second Proxmox node.

A dedicated `pvebackup` dataset (lz4) is exported over NFS to the LAN subnet with `mapall` root, and registered cluster-wide as a Proxmox storage of type `nfs` with content `backup`. Because `/etc/pve` is shared, registering it on one node makes it available to all three.

**Method: scheduled `vzdump` in snapshot mode**, nightly at 02:00, all guests, zstd compression, retention `keep-daily=7,keep-weekly=4,keep-monthly=3`.

`mapall root` on the NFS share is required — without it NFS squashes root and `vzdump` cannot write its dumps.

### Consequences

**Positive:**
- Backups live on **redundant storage on a different physical machine** from the guests. `tank` is RAIDZ1 and scrubbed regularly; the guests' node-local LVM-thin is a single NVMe with no redundancy.
- Snapshot mode means no guest downtime during the nightly run.
- Roughly 14 restore points for ~10GB against multiple TB free — retention is effectively free at this scale.
- First run was verified end to end, and a restore was actually performed and validated (see [Proxmox Backups](../docs/04-proxmox/backups.md)).

**Negative:**
- `vzdump` writes **full backups every run**, not incrementals. At current guest sizes (~10GB compressed per full run) this is irrelevant, but it scales linearly and would become wasteful with more or larger guests.
- **Backup failures are currently silent.** The job notifies the built-in `mail-to-root` target, but the node has no relayhost, no `root` alias, and no local mailbox — so a failing 02:00 job produces no signal anywhere. This is the largest remaining gap and needs a real SMTP or webhook target.
- Backups depend on TrueNAS being up and the NFS export being present. If the share disappears, the job fails — silently, per the previous point.

### Alternatives Considered

**A second Proxmox node as the backup target.** The idle node has ample free thin-pool space and was the initially obvious choice. Rejected because that node is the least reliable machine in the cluster — it has a documented power-delivery fault (see [ADR-0102](0102-pve-node-power-delivery-fix.md)) with hundreds of unsafe shutdowns and daily corosync ring flaps. Putting backups there would mean the backups shared a failure mode with the thing they protect. Backing up to redundant, independently-powered storage is worth more than backing up to convenient storage.

**Proxmox Backup Server (PBS).** Genuinely the better long-term answer: incremental, deduplicated, verifiable, with far smaller storage growth and faster runs. Rejected *for now* purely on time-to-protection — PBS needs its own VM or LXC, storage layout, and configuration, and the cluster needed backups that same evening before firmware work began. Straight `vzdump`-to-NFS was operational in minutes. **This remains the natural upgrade path**, and the NFS dataset can coexist with or be migrated to PBS later.

**TrueNAS-side ZFS snapshots / replication only.** Rejected as insufficient on its own — ZFS snapshots of an NFS share protect the backup files, not the running guests, and Proxmox replication requires ZFS on the Proxmox nodes, which use LVM-thin.

---
