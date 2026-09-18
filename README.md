# Homelab Infrastructure

Documentation of a personal homelab: a TrueNAS SCALE storage server and a
three-node Proxmox VE cluster running about 30 containerized services. The
notes here are written as runbooks and architecture decision records rather
than as a blog, so that a procedure can be followed again later and a past
decision can be understood without reconstructing the reasoning from scratch.

Everything is sanitized for public reading. See [Conventions](#conventions).

## What is running

**TrueNAS SCALE** on a Xeon W-1370 with 32GB RAM. Storage is a 3x4TB RAIDZ1
pool plus cache and boot devices. It hosts roughly 30 services across TrueNAS
Apps and Docker Compose stacks managed through Dockge, including Jellyfin with
hardware transcoding, Immich over 80k photos, Nginx Proxy Manager, Pi-hole,
Tailscale, and a local Ollama and Open WebUI stack on an RTX 3060.

**Proxmox VE cluster** across three Dell OptiPlex Micro nodes: two 3080 Micros
(i5-10500T, 16GB) and one 3000 Micro (i5-12500T, 32GB) that is slated for
replacement after a power delivery fault documented in
[ADR-0102](decisions/0102-pve-node-power-delivery-fix.md). Guests are a Docker
host VM and an Actual Budget LXC, backed up nightly to TrueNAS over NFS. Most
cluster capacity is still idle.

**Network** is a single flat subnet on TP-Link Deco mesh today, with external
access through Tailscale and Nginx Proxy Manager behind Cloudflare DNS. A
segmented OPNsense and VLAN design is written up but not built.

## Worth reading

Three documents carry most of what was actually learned here.

[Diagnosing Hardware by Comparison](docs/10-lessons-learned/diagnosing-hardware-by-comparison.md)
is a retrospective on two faults that appeared in no log file. A cluster node
dropped off the corosync ring about twenty times a day; seven plausible causes
were eliminated by measurement before the real one turned up outside the
machine entirely. The surviving theory was wrong, and the write-up says so.

[Proxmox Backups](docs/04-proxmox/backups.md) covers backup target and method,
how to verify an archive at three levels, a restore test performed against a
live guest, and three layers of failure detection including a dead-man's switch
for the case where the job silently stops running.

[Upgrades and Kernel Pinning](docs/04-proxmox/upgrades-and-kernels.md) documents
converging three nodes onto one kernel and the BIOS flash procedure that came
out of it, including which firmware settings will strand a headless node if
they are lost.

## Documentation

| Path | Contents |
|------|----------|
| `docs/01-architecture/` | High-level design and diagrams |
| `docs/02-hardware/` | Host specifications and capabilities |
| `docs/03-truenas/` | Storage configuration and service inventory |
| `docs/04-proxmox/` | Cluster setup, networking, backups, upgrades |
| `docs/06-networking/` | Current network and the planned VLAN design |
| `docs/07-migration/` | Service migration strategy between hosts |
| `docs/10-lessons-learned/` | Retrospectives |
| `decisions/` | Architecture Decision Records |
| `scripts/` | Helper scripts |

Folder numbers are deliberately non-contiguous. Gaps are reserved for
categories that do not exist yet, so existing paths never have to be renumbered.

## Roadmap

Done:

- Proxmox installed and grown to a three-node cluster
- First VMs and LXC guests deployed
- Nightly `vzdump` backups to TrueNAS over NFS, with a verified restore
- Layered backup failure alerting
- Cluster converged onto a single kernel; firmware brought current

Next:

- Proxmox storage integration with TrueNAS over iSCSI and NFS, replacing
  node-local LVM-thin
- VM templates with cloud-init
- Migrate further services off TrueNAS onto the idle cluster capacity
- Single-node k3s, then multi-node, then GitOps
- OPNsense and the VLAN design in `docs/06-networking/vlan-design.md`
- Deploy the Raspberry Pi nodes, which are bought but still in a drawer

## Goals

Linux administration first, then container orchestration, networking,
security, and infrastructure as code. Working toward CompTIA Network+,
Security+, and Linux+.

Typical pace is five to ten hours a week: an hour or two on weeknights for
reading and small tasks, longer sessions at weekends for anything that risks
taking a service down.

## Conventions

**This repository is public.** Everything committed is sanitized: IPs as
`192.168.x.x` or `10.0.x.x`, internal domains as `example.local`, external as
`example.com`, hostnames generic but descriptive. No real domains, public IPs,
LAN subnets, credentials, or tokens.

A pre-commit hook (`scripts/check-sensitive.sh`) blocks commits containing
secrets or identifying strings. Generic secret patterns live in the script;
repository-specific literals live only in an untracked local file, so they are
never published by the guard that exists to catch them. The hook does not
travel with a clone. To install it:

```bash
cp scripts/check-sensitive.sh .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

ADRs record decisions that had real trade-offs. They are immutable once
accepted; a changed decision gets a new ADR and the old one is marked
superseded, which is why [ADR-0101](decisions/0101-pve-node-acpi-workaround.md)
still sits in the repository documenting a diagnosis that turned out to be
wrong.

Code blocks specify a language. Diagrams are Mermaid so they render and diff
on GitHub. Configuration snippets explain why, not just what.
