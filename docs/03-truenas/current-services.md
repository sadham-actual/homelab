# TrueNAS Current Services

## Service Overview

TrueNAS SCALE 25.10.1 currently hosts services two ways:
- **TrueNAS Apps** (native app store): 8 apps installed, 7 running
- **Dockge/Docker Compose**: 11 active stacks, some of which bundle multiple containers (e.g., the `*arr` media-automation tools run as containers within the `arr` stack rather than as individual TrueNAS Apps)

This replaces an earlier inventory that had drifted out of date — several services listed as "planned" here are now actually running, and a few previously-listed services (NetBird, Watchtower, FlareSolverr) are no longer present.

### TrueNAS Apps

| App | Status |
|-----|--------|
| Immich | Running |
| Tailscale | Running |
| Pi-hole | Running |
| Ollama | Running |
| Nginx Proxy Manager | Running |
| Filebrowser | Running |
| Dockge | Running |
| Unpackerr | Stopped |

### Dockge Stacks (active)

`arr`, `auto-limit`, `n8n`, `navidrome`, `nextcloud`, `octoprint`, `ombi`, `releasarr`, `seerr`, `tracktor`, `uptime-kuma`

Config datasets under `tank/configs/` also show Jellyfin, Sonarr, Radarr, Bazarr, Lidarr, Prowlarr, qBittorrent, Dispatcharr, Cleanuparr, Profilarr, Huntarr, Collabora, Jellyseerr, Dozzle, and Open WebUI — these run as containers within the stacks above rather than as separately-named top-level stacks.

## Critical Services

Services that family members depend on or that provide core infrastructure:

### Jellyfin (Media Streaming)
- **Type:** Docker container (within a dockge stack)
- **Purpose:** Media server for movies, TV shows, and music
- **Storage:** `tank/media` (~1.9TiB used), config at `tank/configs/jellyfin`
- **Special Requirements:** Hardware transcoding via Xeon iGPU (QuickSync); GPU passthrough required if ever migrated to a VM
- **Network:** Accessible via NPM at `jellyfin.example.com`
- **Migration Priority:** Keep on TrueNAS (requires direct GPU access)

### Immich (Photo Backup)
- **Type:** TrueNAS App
- **Purpose:** Photo and video backup with ML-powered organization
- **Storage:** `tank/photos` (~198GiB), uploads/db under `tank/configs/immich`
- **Special Requirements:** ML enabled (face recognition, object detection); direct dataset access for performance
- **Migration Priority:** Keep on TrueNAS (storage-intensive, ML workload)

### Nginx Proxy Manager (Reverse Proxy)
- **Type:** TrueNAS App
- **Purpose:** Reverse proxy with SSL certificate management
- **Users:** Routes all external traffic to internal services
- **Migration Priority:** Keep on TrueNAS initially (critical infrastructure)

### Tailscale (VPN/Remote Access)
- **Type:** TrueNAS App
- **Purpose:** Secure remote access to homelab
- **Migration Priority:** Keep on TrueNAS (always-on requirement)

### Pi-hole (DNS)
- **Type:** TrueNAS App
- **Status:** Now actually deployed and running (previously planned for a Raspberry Pi instead — that plan has not happened; Pi-hole runs on TrueNAS today)
- **Purpose:** Network-wide ad blocking and DNS
- **Migration Priority:** Reassess — original plan was to run this on a Pi for redundancy independent of TrueNAS uptime; that tradeoff is now unaddressed

## Media Automation Stack (`arr` dockge stack)

Sonarr, Radarr, Lidarr, Prowlarr, Bazarr, and qBittorrent run as containers inside the `arr` dockge stack. Functional roles are unchanged from prior documentation:
- **Sonarr / Radarr / Lidarr:** TV/movie/music library management and automation
- **Prowlarr:** Centralized indexer management feeding the above
- **Bazarr:** Automatic subtitle downloads
- **qBittorrent:** Download client (VPN requirement not re-verified this pass — confirm WireGuard/ProtonVPN is still active before relying on this)

Newer additions not previously documented, also under `tank/configs/`:
- **Dispatcharr, Cleanuparr, Profilarr, Huntarr:** Additional `*arr`-ecosystem automation/cleanup tools

## Other Active Services

- **Nextcloud** (dockge) — file sync/storage; new since last inventory. Config at `tank/configs/nextcloud` (~404GiB used)
- **Collabora** (dockge, alongside Nextcloud) — online office document editing
- **n8n** (dockge) — workflow automation
- **Navidrome** (dockge) — Subsonic-compatible music streaming
- **Ollama** (TrueNAS App) + **Open WebUI** (dockge) — local LLM runtime and chat frontend; new since last inventory
- **OctoPrint** (dockge) — controls the Elegoo Centauri Carbon 3D printer over IP
- **Jellyseerr / Ombi** (dockge, `seerr`/`ombi` stacks) — media request interfaces; still redundant with each other, not yet consolidated
- **Tracktor** (dockge) — package tracking, exposed at `tracktor.example.com`
- **Releasarr** (dockge) — release notifications
- **Auto-limit** (dockge) — automated `*arr` rate limiting
- **Uptime Kuma** (dockge) — service monitoring
- **Dozzle** (dockge) — real-time Docker log viewer
- **Dockge** (TrueNAS App) — manages the compose stacks above; config/compose files at `tank/stacks`
- **Filebrowser** (TrueNAS App) — web-based file manager with dataset access
- **Unpackerr** (TrueNAS App, currently stopped) — archive extraction helper for the `*arr` stack

## No Longer Present

Previously documented but not found in the current dataset/app inventory — likely decommissioned:
- **NetBird** — redundant with Tailscale, matches prior note that it might be removed
- **Watchtower** — automatic container updates
- **FlareSolverr** — Cloudflare bypass for indexers

## Storage Summary

- Pool `tank`: RAIDZ1, ~10.9TiB usable capacity, ~48% allocated (healthy, most recent scrub finished clean)
- SMB shares: `photos` (`tank/photos`), `timemachine-user` (`tank/timemachine-user`, Time Machine backup target)
- NFS shares: `media` (`tank/media`), `appdata` (`tank/appdata`)

## Network Access Summary

**Services with external access (via NPM), confirmed subdomains:**
- `jellyfin.example.com`
- `tracktor.example.com`

Other subdomains referenced in earlier docs (jellyseerr, etc.) were not re-verified this pass — confirm NPM proxy host list directly before relying on this.

**Services accessible only via Tailscale or local network:** everything else in the inventory above, via direct IP:PORT or Tailscale.

## Notes for Next Review

- Confirm qBittorrent's VPN (WireGuard/ProtonVPN) is still active — not re-verified this pass.
- Confirm exact container membership within the `arr` and `releasarr` dockge stacks (this pass inferred membership from dataset folder names, not from reading the actual compose files).
- Re-verify NPM proxy host list for the full current subdomain mapping.

---

*Last Updated: 2026-07-23*
