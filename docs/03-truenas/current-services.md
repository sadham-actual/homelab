# TrueNAS Current Services

## Service Overview

TrueNAS SCALE currently hosts 26 services across two deployment methods:
- **TrueNAS Apps** (5 services): Native app store applications
- **Dockge/Docker Compose** (21 services): Containerized applications managed via Docker Compose

## Critical Services

Services that family members depend on or that provide core infrastructure:

### Jellyfin (Media Streaming)
- **Type:** Dockge/Docker Compose
- **Purpose:** Media server for movies, TV shows, and music
- **Users:** Family members actively use for streaming
- **Storage:** `/tank/media` (1.22TB)
- **Special Requirements:** 
  - Hardware transcoding via Xeon iGPU (QuickSync)
  - GPU passthrough required if migrated to VM
- **Network:** Accessible via NPM at jellyfin.example.com
- **Migration Priority:** Keep on TrueNAS (requires direct GPU access)

### Immich (Photo Backup)
- **Type:** TrueNAS App
- **Purpose:** Photo and video backup with ML-powered organization
- **Users:** Personal photo backup (80,000+ photos/videos)
- **Storage:** `/tank/photos` (250GB)
- **Special Requirements:**
  - Machine learning enabled (face recognition, object detection)
  - Direct dataset access for performance
- **Migration Priority:** Keep on TrueNAS (storage-intensive, ML workload)

### Nginx Proxy Manager (Reverse Proxy)
- **Type:** TrueNAS App
- **Purpose:** Reverse proxy with SSL certificate management
- **Users:** Routes all external traffic to internal services
- **Network:** Manages SSL for *.example.com domains
- **Special Requirements:**
  - Ports 80/443 forwarded from router
  - Cloudflare SSL/TLS integration
- **Migration Priority:** Keep on TrueNAS initially (critical infrastructure)

### Tailscale (VPN/Remote Access)
- **Type:** TrueNAS App
- **Purpose:** Secure remote access to homelab
- **Users:** Personal remote access to all services
- **Migration Priority:** Keep on TrueNAS (always-on requirement)

### Pi-hole (DNS)
- **Type:** Not yet deployed
- **Purpose:** Network-wide ad blocking and DNS
- **Planned Deployment:** Raspberry Pi for redundancy
- **Migration Priority:** Deploy on Pi, not TrueNAS or Proxmox

## Media Automation Stack (*arr)

Complete media management and automation suite:

### Sonarr (TV Show Management)
- **Type:** Dockge/Docker Compose
- **Purpose:** TV show library management and automation
- **Storage:** `/tank/media/tv`
- **Integration:** Connects to Prowlarr, qBittorrent, Jellyfin
- **Migration Priority:** Medium - could move to Proxmox VM or k8s

### Radarr (Movie Management)
- **Type:** Dockge/Docker Compose
- **Purpose:** Movie library management and automation
- **Storage:** `/tank/media/movies`
- **Integration:** Connects to Prowlarr, qBittorrent, Jellyfin
- **Migration Priority:** Medium - could move to Proxmox VM or k8s

### Lidarr (Music Management)
- **Type:** Dockge/Docker Compose
- **Purpose:** Music library management and automation
- **Storage:** `/tank/media/music`
- **Integration:** Connects to Prowlarr, qBittorrent, Navidrome
- **Migration Priority:** Low - could move to k8s

### Prowlarr (Indexer Manager)
- **Type:** Dockge/Docker Compose
- **Purpose:** Centralized indexer management for *arr stack
- **Integration:** Feeds search results to Sonarr, Radarr, Lidarr
- **Migration Priority:** Medium - move with other *arr apps

### Bazarr (Subtitle Management)
- **Type:** Dockge/Docker Compose
- **Purpose:** Automatic subtitle download for movies and TV
- **Integration:** Works with Sonarr, Radarr, Jellyfin
- **Migration Priority:** Low - nice to have

### qBittorrent (Download Client)
- **Type:** Dockge/Docker Compose
- **Purpose:** Torrent client for media downloads
- **Storage:** `/tank/media/downloads`
- **Special Requirements:**
  - VPN connection via WireGuard (ProtonVPN)
  - Must maintain VPN at all times
- **Migration Priority:** Medium - keep on TrueNAS or move to dedicated VM with VPN

## Supporting Services

### Jellyseerr (Media Requests)
- **Type:** Dockge/Docker Compose
- **Purpose:** User-friendly interface for requesting media
- **Integration:** Interfaces with Sonarr, Radarr, Jellyfin
- **Users:** Family can request movies/TV shows
- **Migration Priority:** Low - could move to k8s

### Ombi (Alternative Request System)
- **Type:** Dockge/Docker Compose
- **Purpose:** Alternative media request interface (redundant with Jellyseerr?)
- **Migration Priority:** Low - consider consolidating with Jellyseerr

### FlareSolverr (Cloudflare Bypass)
- **Type:** Dockge/Docker Compose
- **Purpose:** Bypass Cloudflare protection for indexers
- **Integration:** Used by Prowlarr
- **Migration Priority:** Low - move with Prowlarr

### Profilarr (*arr Profile Manager)
- **Type:** Dockge/Docker Compose
- **Purpose:** Manages quality profiles across *arr apps
- **Migration Priority:** Low

## Network & Monitoring

### NetBird (Alternative VPN)
- **Type:** Dockge/Docker Compose
- **Purpose:** WireGuard-based VPN (experimental, not actively used)
- **Migration Priority:** Low - may decommission in favor of Tailscale

### Uptime Kuma (Service Monitoring)
- **Type:** Dockge/Docker Compose
- **Purpose:** Monitor uptime and health of homelab services
- **Migration Priority:** High - good candidate for first VM migration to Proxmox

### Dozzle (Docker Log Viewer)
- **Type:** Dockge/Docker Compose
- **Purpose:** Real-time Docker container log viewing
- **Migration Priority:** Low - useful for TrueNAS but not needed on Proxmox

## Automation & Utilities

### n8n (Workflow Automation)
- **Type:** Dockge/Docker Compose
- **Purpose:** Automation workflows (IFTTT alternative)
- **Migration Priority:** Medium - good k8s candidate for learning

### Tracktor (Package Tracking)
- **Type:** Dockge/Docker Compose
- **Purpose:** Track shipping packages
- **Network:** Accessible via tracktor.example.com
- **Migration Priority:** Low - could move to k8s

### Releasarr (Release Notifications)
- **Type:** Dockge/Docker Compose
- **Purpose:** Notifications for new media releases
- **Migration Priority:** Low

### Watchtower (Container Updates)
- **Type:** Dockge/Docker Compose
- **Purpose:** Automatically update Docker containers
- **Migration Priority:** Keep on TrueNAS (manages local containers)

### Auto-Limit (*arr Rate Limiting)
- **Type:** Dockge/Docker Compose
- **Purpose:** Automatically adjust *arr rate limits
- **Migration Priority:** Low - move with *arr stack

## Media Playback & Management

### Navidrome (Music Server)
- **Type:** Dockge/Docker Compose
- **Purpose:** Subsonic-compatible music streaming server
- **Storage:** `/tank/media/music`
- **Migration Priority:** Low - alternative to Jellyfin for music

## 3D Printing

### OctoPrint (3D Printer Management)
- **Type:** Dockge/Docker Compose
- **Purpose:** Control and monitor Elegoo Centauri Carbon 3D printer
- **Connection:** IP-based (not USB)
- **Migration Priority:** Medium - could move to Raspberry Pi or Proxmox VM

## Management Interfaces

### Dockge (Docker Compose Manager)
- **Type:** Dockge/Docker Compose
- **Purpose:** Web UI for managing Docker Compose stacks
- **Storage:** `/tank/stacks` (compose files)
- **Migration Priority:** Keep on TrueNAS (manages local stacks)

### File Browser
- **Type:** TrueNAS App
- **Purpose:** Web-based file manager
- **Storage:** Access to all datasets
- **Migration Priority:** Keep on TrueNAS (direct dataset access)

## Service Migration Strategy

### Keep on TrueNAS (High Priority)
These services should remain on TrueNAS due to hardware requirements, storage access, or criticality:
1. **Jellyfin** - Requires iGPU for transcoding
2. **Immich** - Heavy storage I/O, ML workload
3. **Tailscale** - Core infrastructure, must stay up
4. **Nginx Proxy Manager** - Critical reverse proxy (initially)
5. **Dockge** - Manages remaining TrueNAS containers
6. **File Browser** - Direct dataset access
7. **Watchtower** - Updates TrueNAS containers

### Move to Proxmox VMs (Medium Priority)
Good candidates for VM migration to learn VM management:
1. **Uptime Kuma** - Simple, stateless, good first migration
2. **qBittorrent + VPN** - Isolated environment for downloads
3. **n8n** - Self-contained automation platform
4. **OctoPrint** - Could run on dedicated VM or Pi

### Move to Kubernetes (Lower Priority)
Suitable for k8s learning after cluster is established:
1. ***arr stack** (Sonarr, Radarr, Lidarr, Prowlarr, Bazarr) - Stateless with shared config
2. **Jellyseerr/Ombi** - Web frontends, minimal state
3. **Tracktor** - Simple web app
4. **Navidrome** - Music streaming
5. **n8n** - Cloud-native automation

### Decommission/Consolidate
Consider removing or consolidating:
1. **NetBird** - Redundant with Tailscale
2. **Ombi** - Redundant with Jellyseerr
3. **Releasarr** - Evaluate if still needed

## Resource Usage Analysis

### Storage-Heavy Services
- **Jellyfin:** 1.22TB (media library)
- **Immich:** 250GB (photos)
- **qBittorrent:** Variable (downloads)

These benefit from direct TrueNAS dataset access.

### CPU-Intensive Services
- **Jellyfin:** Heavy when transcoding (uses iGPU)
- **Immich:** ML processing (face/object recognition)
- ***arr stack:** Light CPU usage

### Network-Heavy Services
- **qBittorrent:** High bandwidth when downloading
- **Jellyfin:** High bandwidth when streaming remotely
- **Nginx Proxy Manager:** All external traffic routes through

### Always-On Requirements
- **Tailscale:** Required for remote access
- **Nginx Proxy Manager:** Routes external traffic
- **Jellyfin:** Family expects 24/7 availability

## Docker Compose File Locations

All compose files stored in: `/tank/stacks/`

**Directory structure:**
```
/tank/stacks/
├── uptime-kuma/
│   └── docker-compose.yml
├── tracktor/
│   └── docker-compose.yml
├── arr-stack/
│   ├── docker-compose.yml (or individual files per service)
│   └── ...
├── jellyfin/
│   └── docker-compose.yml
└── [other services]/
    └── docker-compose.yml
```

**Backup Strategy:**
- All compose files should be committed to Git (sanitized)
- Configs stored in `/tank/configs`
- Before migration, backup entire `/tank/stacks` and `/tank/configs`

## Pre-Migration Checklist

Before migrating any service:
- [ ] Document current configuration
- [ ] Export/backup service data
- [ ] Test service in new environment (parallel run)
- [ ] Verify functionality matches original
- [ ] Update DNS/proxy if needed
- [ ] Monitor for 24-48 hours before decommissioning original
- [ ] Keep backup of original config for 30 days

## Network Access Summary

**Services with external access (via NPM):**
- jellyfin.example.com → Jellyfin
- tracktor.example.com → Tracktor
- jellyseerr.example.com → Jellyseerr (presumably)

**Services accessible only via Tailscale:**
- All *arr apps
- Dockge
- Uptime Kuma
- n8n
- OctoPrint
- File Browser
- Dozzle

**Services accessible on local network:**
- All services (via direct IP:PORT)

## Dependencies Map

**Jellyfin depends on:**
- `/tank/media` dataset
- Xeon iGPU for transcoding
- Network access (NPM or Tailscale)

***arr stack depends on:**
- qBittorrent (download client)
- Prowlarr (indexers)
- `/tank/media` dataset
- Jellyfin (to update library)

**qBittorrent depends on:**
- ProtonVPN WireGuard config
- `/tank/media/downloads` dataset

**Nginx Proxy Manager depends on:**
- Ports 80/443 forwarded
- Cloudflare DNS/SSL
- Access to backend services

**Immich depends on:**
- `/tank/photos` dataset
- CPU/GPU for ML processing
- Database (PostgreSQL)

## Monitoring Recommendations

**Before major changes:**
1. Set up Uptime Kuma to monitor all critical services
2. Document baseline performance (CPU, RAM, network)
3. Create TrueNAS snapshots of all datasets
4. Export all Docker Compose files to Git

**During migration:**
1. Run new and old services in parallel
2. Compare functionality and performance
3. Monitor resource usage on both platforms
4. Keep rollback plan ready

**After migration:**
1. Monitor for 7 days before removing old service
2. Keep configuration backups for 30 days
3. Document lessons learned

---

*Last Updated: 2025-01-26*