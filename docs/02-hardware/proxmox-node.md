# Proxmox Cluster Hardware

## Cluster Overview

The Proxmox VE cluster is named `homelab` and currently has three nodes, all Dell OptiPlex Micro form-factor desktops. All three joined the cluster and are quorate (2-of-3 minimum for quorum).

| Node | Model | CPU | RAM | Storage | Role |
|------|-------|-----|-----|---------|------|
| `pve-01` | Dell OptiPlex 3080 Micro | i5-10500T (6C/12T) | 16GB DDR4-2400 | 256GB NVMe | Primary — hosts current VMs/LXCs |
| `pve-02` | Dell OptiPlex 3000 Micro | i5-12500T (6C/12T) | 32GB DDR4-3200 | 512GB NVMe | Idle — see power delivery note below |
| `pve-03` | Dell OptiPlex 3080 Micro | i5-10500T (6C/12T) | 16GB DDR4-2666 | 256GB NVMe | Idle |

All three nodes: single Gigabit Ethernet NIC, connected to `vmbr0` on the flat `192.168.1.0/24` network (no VLANs yet — see [Networking: Current Setup](../06-networking/current-setup.md)).

**Note on RAM:** Earlier planning docs assumed 40GB on a single node; actual installed RAM (confirmed via `dmidecode`) is 16GB on each 3080 Micro and 32GB on the 3000 Micro.

## Known Issue: pve-02 Power Delivery

`pve-02` is currently powered by a dedicated 100W USB-C PD brick rather than the shared power rig used by the other two nodes (one upstream supply feeding 5x 65W USB-C PD trigger boards → USB-C-to-Dell-barrel adapters). The shared rig could not reliably deliver the current spike from bringing all 12 threads online, causing a boot crash-loop; the dedicated 100W brick resolved it. Full writeup: [ADR-0102](../../decisions/0102-pve-node-power-delivery-fix.md) (supersedes the earlier, incorrect ACPI-based diagnosis in [ADR-0101](../../decisions/0101-pve-node-acpi-workaround.md)).

**Follow-up not yet done:** verify whether `pve-01`/`pve-03` have similar headroom issues on the shared rig under full load — they haven't shown the symptom, but haven't been stress-tested at full core count on that supply either.

## Current Workloads

All current VMs/LXCs run on `pve-01`; `pve-02` and `pve-03` have no workloads assigned yet.

| ID | Name | Type | Status | vCPU | RAM | Disk | Notes |
|----|------|------|--------|------|-----|------|-------|
| 100 | openclaw-1 | VM | stopped | 2 | 4GB | 40GB | Ubuntu 24.04 Desktop |
| 101 | docker-1 | VM | running | 4 | 8GB | 64GB | Ubuntu 24.04 Server, general-purpose Docker host, `onboot=1` |
| 103 | actualbudget | LXC | running | 2 | 2GB | 4GB | Debian, unprivileged, deployed via community-scripts.org Proxmox VE script, `onboot=1` |

Local storage on each node: `local` (directory) + `local-lvm` (LVM-thin). No TrueNAS iSCSI/NFS storage is attached to Proxmox yet — VM disks are all on node-local LVM-thin.

## Planned / Not Yet Done

These items from the original hardware plan have not happened yet:
- TrueNAS iSCSI LUN or NFS mount added as Proxmox storage (VMs currently use only local-lvm)
- k3s deployment (no Kubernetes installed anywhere in the homelab as of this writing)
- OPNsense VM / VLAN network migration (still flat `192.168.1.0/24`)
- Second/third node workload distribution — `pve-02` and `pve-03` are online but idle

## Maintenance Notes

- SSH access: `root@<node-ip>` with key auth (see `~/.ssh/config` aliases `pve-01`/`pve-02`/`pve-03` on the management workstation).
- Before touching `pve-02`'s boot configuration again, read [ADR-0102](../../decisions/0102-pve-node-power-delivery-fix.md) first — the original ACPI diagnosis was wrong and cost real troubleshooting time.

---

*Last Updated: 2026-07-23*
