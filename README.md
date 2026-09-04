# homelab
Documentation of my homelab journey. 
# Homelab Infrastructure Documentation

Personal homelab for learning enterprise infrastructure, containerization, and networking concepts while preparing for CompTIA Network+, Security+, and Linux+ certifications.

## Overview

This homelab consists of:
- **TrueNAS SCALE** - Centralized storage and current service host
- **Proxmox VE** - 3-node cluster for VMs and future Kubernetes cluster (mostly idle capacity currently)
- **Future OPNsense** - Network segmentation and security (planned)
- **Raspberry Pi nodes** - Edge services and high availability (planned)

## Current State

### Hardware
- **TrueNAS Server**: Xeon W-1370, 32GB RAM, 3x 4TB RAIDZ1 + cache/boot drives
- **Proxmox Cluster**: 3x Dell OptiPlex Micro nodes (2x 3080 Micro/i5-10500T/16GB, 1x 3000 Micro/i5-12500T/32GB) — see [Proxmox Cluster Hardware](docs/02-hardware/proxmox-node.md)
- **Edge Nodes**: 2x Raspberry Pi 4, 1x Pi Zero 2W (available for deployment, not yet deployed)

### Services (~30 running on TrueNAS)
See [Current Services](docs/03-truenas/current-services.md) for complete inventory.

**Critical Services:**
- Jellyfin (family media streaming with hardware transcoding)
- Immich (80k+ photos, ML-enabled backup)
- Nginx Proxy Manager (reverse proxy with SSL)
- Tailscale (remote access)
- *arr stack (media automation)

### Network
- Current: TP-Link Deco mesh (192.168.1.0/24, single subnet)
- Planned: OPNsense router/firewall with VLAN segmentation
- Domain: example.com (Cloudflare DNS + proxy)
- External access: Tailscale (primary), NPM with SSL (ports 80/443 forwarded)

## Goals

### Learning Objectives (Priority Order)
1. **Linux Administration** - Deep systems knowledge, scripting, automation
2. **Kubernetes** - Container orchestration, GitOps, cloud-native patterns
3. **Networking** - VLANs, routing, firewalls, network segmentation
4. **Security** - Hardening, monitoring, incident response
5. **Infrastructure as Code** - Terraform, Ansible, declarative infrastructure

### Certifications
- CompTIA Network+
- CompTIA Security+
- CompTIA Linux+

### Technical Goals
- Learn VM management and hypervisor operations
- Deploy and manage production-ready Kubernetes cluster
- Implement proper network segmentation with VLANs
- Build CI/CD pipelines for homelab automation
- Maintain high availability for family-critical services

## Project Roadmap

### Phase 1: Foundation (Weeks 1-2)
- [x] Install and configure Proxmox — grew to a 3-node cluster (`homelab`), not just the single Dell 3080 Micro originally planned
- [ ] Integrate Proxmox storage with TrueNAS (iSCSI + NFS) — VMs currently use only node-local LVM-thin
- [ ] Set up automated snapshots on TrueNAS
- [x] Deploy first test VMs (Ubuntu 24.04 Desktop + Server, not Rocky Linux)

### Phase 2: VM Learning (Weeks 3-4)
- [ ] Create VM templates with cloud-init
- [ ] Practice snapshots, cloning, and backups — snapshots and backups exercised; VM cloning/templates still untouched
- [ ] Deploy monitoring VM (Uptime Kuma or Grafana) — Uptime Kuma is running, but on TrueNAS/dockge, not as a Proxmox VM
- [x] Experiment with LXC containers — `actualbudget` LXC running on Proxmox

### Phase 3: Service Migration Experiments (Weeks 5-8)
- [ ] Migrate 2-3 non-critical services to Proxmox — one LXC (actualbudget) migrated; two of three cluster nodes still have no workloads
- [ ] Document performance differences
- [x] Establish backup workflow to TrueNAS — nightly `vzdump` to a TrueNAS NFS dataset ([ADR-0006](decisions/0006-proxmox-backup-strategy.md), [runbook](docs/04-proxmox/backups.md))
- [x] Test rollback procedures — restore verified end to end, incl. SQLite integrity check on restored data

### Phase 4: Kubernetes Foundation (Weeks 9-12)
- [ ] Deploy single-node k3s cluster in VM
- [ ] Configure TrueNAS NFS for persistent storage
- [ ] Deploy first stateless applications
- [ ] Set up kubectl and basic monitoring

### Phase 5: Network Upgrade (Future)
- [ ] Plan OPNsense migration strategy
- [ ] Design VLAN architecture
- [ ] Select managed switch and WiFi APs
- [ ] Implement phased cutover

### Phase 6: Advanced Patterns (Ongoing)
- [ ] Multi-node k3s cluster
- [ ] GitOps with FluxCD/ArgoCD
- [ ] CI/CD runners in Kubernetes
- [ ] Integrate Raspberry Pi nodes

## Documentation Structure

- **docs/01-architecture/** - High-level design decisions and diagrams
- **docs/02-hardware/** - Hardware specifications and capabilities
- **docs/03-truenas/** - Storage configuration and service management
- **docs/04-proxmox/** - Virtualization platform setup and usage
- **docs/05-kubernetes/** - Container orchestration and deployments
- **docs/06-networking/** - Network design, VLANs, and security
- **docs/07-migration/** - Service migration strategies and decisions
- **docs/08-monitoring/** - Observability and alerting
- **docs/09-security/** - Hardening, backups, and disaster recovery
- **docs/10-lessons-learned/** - Journey journal and retrospectives
- **configs/** - Sanitized configuration files
- **scripts/** - Automation and helper scripts
- **decisions/** - Architecture Decision Records (ADRs)

## Quick Links

- [Architecture Overview](docs/01-architecture/overview.md)
- [Current Network Design](docs/06-networking/current-setup.md)
- [Service Inventory](docs/03-truenas/current-services.md)
- [Migration Strategy](docs/07-migration/migration-strategy.md)
- [Proxmox Cluster Hardware](docs/02-hardware/proxmox-node.md)
- [Proxmox Backups](docs/04-proxmox/backups.md)
- [Upgrades and Kernel Pinning](docs/04-proxmox/upgrades-and-kernels.md)
- [Diagnosing Hardware by Comparison](docs/10-lessons-learned/diagnosing-hardware-by-comparison.md)

## Time Commitment

**Typical weekly schedule:** 5-10 hours
- Weeknight sessions: 1-2 hours for reading, planning, small tasks
- Weekend deep-dives: 3-6 hours for major implementations

**Learning style:** Deep-dive, hands-on experimentation with concept explanations

## Repository Conventions

### Sanitization
- IP addresses: `192.168.X.X` or `10.0.X.X`
- Domain names: `example.local` (internal), `example.com` (external)
- Hostnames: Descriptive but generic (e.g., `truenas-01`, `pve-node-01`)

### Git Workflow
- Main branch: Stable, tested documentation
- Feature branches: For major documentation additions
- Commit messages: Descriptive (e.g., "Add Proxmox storage integration guide")

### Code Blocks
- Always specify language for syntax highlighting
- Include comments explaining non-obvious configurations
- Provide context for why choices were made

## Contributing (Future)

This repository is currently private for personal learning. May be made public in the future as a resource for others building similar homelabs.

## License

Personal documentation - all rights reserved (for now)