# ADR-0007: Expansion Pool Layout (3x 6-wide RAIDZ2)

**Date:** 2026-10-30

**Status:** Accepted

### Context

The TrueNAS data pool `tank` is a single 3x4TB RAIDZ1 vdev (~7.1 TiB usable, ~5 TB used, ~68% full). RAIDZ1 survives exactly one drive failure, and a RAIDZ1 vdev cannot be converted to RAIDZ2 in place, so any move to double parity means building a new pool and migrating into it.

The server is moving into a 20-bay rackmount chassis:

- Five 4-bay backplanes with SAS-capable drive connectors. Each backplane takes four individual SATA-style data cables rather than a single SFF-8087.
- An LSI 9300-8i HBA (IT mode) dual-linked to an Adaptec AEC-82885T SAS expander. The expander's ports A-E each feed one backplane through an SFF-8643-to-4x-SATA breakout.

That gives up to 20 drive bays on one controller path. The constraints that shaped the choice:

- **Drives are used 4TB enterprise disks**, bought a few at a time. Two SAS drives are on hand, plus the three SATA drives already in `tank`. Used drives raise the odds of a second failure during a resilver.
- **Capacity need is modest.** ~5 TB used today, and nothing on the roadmap approaches 40 TiB.
- **Every client is at 2.5GbE or slower.** Sequential throughput beyond ~1 GB/s cannot be observed from anywhere on the network today.
- **Apps and databases are moving to a separate NVMe mirror**, so the HDD pool mostly serves media, photos, file sync and backups. That workload is mostly sequential, with some small-file random reads (photo thumbnails, sync clients).
- **The existing pool must stay online** during the migration, so the first new vdev has to hold all current data with headroom.

### Decision

**Build the new pool as three 6-wide RAIDZ2 vdevs: 18 drives, ~43.7 TiB of data capacity before ZFS overhead.** The remaining two bays stay empty, for drive burn-in and for replacing a failing disk while it is still attached.

Migration order:

1. Buy four more 4TB drives. With the two SAS drives on hand, build **vdev 1** (6 drives) as a new pool while `tank` keeps running on its own backplane.
2. Replicate everything with `zfs send -R`, verify, and repoint services.
3. Destroy `tank`. Its three drives plus three new ones become **vdev 2** (~29 TiB of data capacity).
4. Add **vdev 3** (6 more drives) when the pool approaches ~70% full.

Every vdev is built at full width from the start. RAIDZ expansion is not used.

### Consequences

**Positive:**
- **Two-drive fault tolerance per vdev**, appropriate for used drives. A second failure during a ~4TB resilver does not lose the pool.
- **Clean migration.** Each vdev is created at its final width, so there are no RAIDZ-expansion caveats: old data stuck at the pre-expansion parity ratio, and under-reported capacity.
- **Three vdevs give ~50% more random-read IOPS** than the two-vdev alternatives. That helps thumbnail browsing and small-file sync.
- **Drive-size upgrades come in 6-drive steps.** A vdev grows once all of its members are replaced, so replacing 6 drives at a time is cheaper than replacing 9 or 10.
- **Two free bays** for burn-in and safe in-place replacement.
- 4 data disks per vdev (6-wide RAIDZ2) allocates cleanly at the default recordsize.

**Negative:**
- **67% space efficiency.** Six of the 18 drives are parity. Wider layouts get 16-30% more capacity from the same bays.
- **Lower sequential ceiling** than a 2x9 layout: 12 data disks against 14, roughly 1.2-1.6 GB/s against 1.4-1.9 GB/s realistic. Both exceed 10GbE while the pool has headroom, and neither difference is visible from 2.5GbE clients.
- **18 spinning drives draw roughly 110-130W at idle.** That is a real running cost for 4TB disks, and it pushes a UPS higher up the priority list.

### Alternatives Considered

| Layout | Drives | Data disks | ~Data TiB | Survives | Vdevs | Why not chosen |
|---|---|---|---|---|---|---|
| 2x 9-wide RAIDZ2 | 18 | 14 | 50.9 | 2 / vdev | 2 | Closest runner-up: +16% capacity from the same 18 drives, keeps 2 free bays. Building it incrementally needs RAIDZ expansion (6 -> 9), drive upgrades come in 9-drive steps, and it has fewer IOPS. The extra capacity is not needed. |
| 2x 10-wide RAIDZ2 | 20 | 16 | 58.2 | 2 / vdev | 2 | Most capacity with double parity, but no free bays, 10-drive upgrade steps, and either 8 drives up front or RAIDZ expansion. |
| 2x 8-wide RAIDZ2 | 16 | 12 | 43.7 | 2 / vdev | 2 | Same capacity as the chosen layout from 2 fewer drives, but fewer IOPS. It also needs 8 drives up front or expansion, and strands 4 bays that can't form another vdev of the same width. |
| 2x 10-wide RAIDZ3 | 20 | 14 | 50.9 | 3 / vdev | 2 | Triple parity is more protection than 4TB drives with ~8h resilvers need. Also no free bays and 10-drive steps. |
| 10x 2-way mirrors | 20 | 10 | 36.4 | 1 / pair | 10 | Best IOPS and cheapest growth (2 drives at a time), but only 50% efficiency, and losing both disks of any pair loses the pool. The IOPS advantage matters less once apps live on NVMe. |
| 4x 5-wide RAIDZ1 | 20 | 16 | 58.2 | 1 / vdev | 4 | Single parity on used drives repeats the risk this migration exists to remove. |
| dRAID2 (20 children, 1 distributed spare) | 20 | ~15 | ~55 | 2 + fast rebuild | 1 | Designed for 30+ drive pools. Fixed stripe width wastes space on small files, the vdev cannot be widened, and it effectively needs every drive bought up front. |

**Why rejected, in short:** the capacity gained by going wider is capacity this homelab will not use before 4TB drives are worth replacing anyway. The chosen layout trades that unused capacity for a simpler migration, more IOPS, cheaper upgrades and two free bays.

---
