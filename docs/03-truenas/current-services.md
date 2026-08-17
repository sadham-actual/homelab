# TrueNAS Current Services

## Service Overview

TrueNAS SCALE 25.10.1 currently hosts services two ways:
- **TrueNAS Apps** (native app store): 8 apps installed, 7 running (Unpackerr is stopped)
- **Dockge/Docker Compose**: 11 active stacks, some of which bundle multiple containers (e.g., the `*arr` media-automation tools run as containers within the `arr` stack rather than as individual TrueNAS Apps)

This replaces an earlier inventory that had drifted out of date — several services listed as "planned" here are now actually running, and a few previously-listed services (NetBird, Watchtower, FlareSolverr) are no longer present.

### TrueNAS Apps

| App | Status |
|-----|--------|
| Immich | Running |
| Tailscale | Running |
| Pi-hole | Running |
| Ollama | Running — see [Local AI stack](#local-ai-stack-ollama--open-webui) |
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
- **Ollama** (TrueNAS App) + **Open WebUI** (TrueNAS App) — local LLM runtime and chat frontend; see [Local AI Stack](#local-ai-stack-ollama--open-webui) below
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

## Local AI Stack (Ollama + Open WebUI)

| Component | Deployment | State |
|-----------|-----------|-------|
| Ollama | TrueNAS App | Running (v0.32.11), GPU allocated in app config |
| Open WebUI | TrueNAS App | Running — Standard image on port `31028`, pointed at the Ollama app |

### Reaching the Ollama API

The Ollama app does **not** publish the conventional port 11434 on the host. TrueNAS
Apps remap ports, and this one is reachable at **port 30068**:

```bash
# Confirm Ollama is alive and get its version
curl -s http://192.168.1.50:30068/api/version

# List locally pulled models
curl -s http://192.168.1.50:30068/api/tags
```

Substitute the TrueNAS host's own address. This is worth recording because probing
`11434` returns nothing and makes a perfectly healthy Ollama look stopped — a
mistake already made once against this box.

### Open WebUI image selection

The TrueNAS Open WebUI app offers three images. With Ollama already running as its
own app, **Standard** is the correct choice:

| Image option | Use when |
|--------------|----------|
| **Standard** (OpenAPI / external Ollama) | ✅ Correct here — thin frontend, talks to the existing Ollama app over HTTP |
| Ollama (bundled) | Would run a *second* Ollama instance, duplicating model storage and contending for the same GPU |
| Cuda | For Open WebUI's own GPU features (RAG embeddings, Whisper STT) — not needed for chat, and competes for VRAM |

Point it at the Ollama app via environment variable:

```
OLLAMA_BASE_URL = http://192.168.1.50:30068
```

Use the host's LAN address, **not** `localhost` — Open WebUI runs in its own Docker
bridge network, so `localhost` inside that container resolves to the container
itself. This is the most common Open WebUI connection failure.

**Ports in use by the local AI stack:**

| Service | Host port |
|---------|-----------|
| Ollama API | `30068` |
| Open WebUI | `31028` |

Neither is the upstream project's documented default (11434 and 8080 respectively) —
TrueNAS Apps assign host ports from the 30000+ range, so always look up the actual
port in the app's config rather than assuming.

The `WEBUI_SECRET_KEY` signs session JWTs. Set it explicitly (`openssl rand -hex 32`)
rather than leaving it blank, so sessions survive an app redeploy; store it in a
password manager and **never commit it here**. Changing it logs every user out.

### Locally pulled models

| Model | Size | Context |
|-------|------|---------|
| `llama3.1:8b-instruct-q4_K_M` | 4.9 GB | 131k |
| `qwen2.5:7b-instruct` | 4.7 GB | 32k |
| `mistral:7b-instruct` | 4.4 GB | 32k |
| `qwen2.5:14b-instruct-q4_K_M` | 9.0 GB | 32k |

The 7–8B models sit comfortably in 12GB VRAM with room for context. The 14B fits but
leaves only ~3GB for KV cache, so it degrades at longer context.

### Verifying GPU use

**Verified working (2026-08-16).** Measured baseline on `llama3.1:8b-instruct-q4_K_M`:

| Metric | Value |
|--------|-------|
| Throughput | ~67 tok/s |
| VRAM placement | 5.27 / 5.27 GB — 100% on GPU |
| GPU utilization during generation | 99% |
| Temperature under load | 62°C (55°C idle) |
| Cold model load from disk | ~8 s |

Keep these numbers as the reference point. A 7–8B model generating at single-digit
tok/s means it has fallen back to CPU.

**The authoritative check is `size_vram`, not `nvidia-smi`:**

```bash
# size_vram should equal size; 0 means the model is entirely in system RAM
curl -s http://192.168.1.50:30068/api/ps
```

Two traps, both hit during the initial bring-up:

1. **An idle Ollama reports `size_vram: 0` and 0 MiB in `nvidia-smi`.** Models unload
   after the `keep_alive` timeout (5 minutes default). Zero VRAM at idle is normal
   and is *not* evidence of a CPU fallback — check during or right after a
   generation, never at rest.
2. **Container IDs churn.** TrueNAS recreates app containers on config changes, so an
   ID captured minutes earlier may not exist. Always resolve by name
   (`docker ps -qf name=ollama`) rather than reusing an ID.

The fastest confirmation needs no shell at all: Open WebUI reports tokens/sec under
each response (click the info icon), and Ollama's startup log — viewable in Dozzle —
prints the line that settles whether CUDA initialized:

```
msg="inference compute" library="CUDA" name="CUDA0"
description="NVIDIA GeForce RTX 3060" total="11.6 GiB" available="11.5 GiB"
```

A container denied GPU access does not error. It silently falls back to CPU, and the
only symptom is slow generation — which is why these checks are worth doing
explicitly rather than by feel.

### Context length defaults to 4096

Ollama sizes a default context from available VRAM and logs its choice at startup:

```
msg="vram-based default context" total_vram="11.6 GiB" default_num_ctx="4096"
```

So `llama3.1:8b` runs at **4096 tokens by default despite supporting 131k**. This is
Ollama's own VRAM-based heuristic, not an Open WebUI setting. To raise it, either set
`OLLAMA_CONTEXT_LENGTH` in the Ollama app config, or override `num_ctx` in Open
WebUI's per-model advanced parameters. Longer context costs VRAM, so raise it
deliberately and re-check `size_vram` afterward to confirm the model still fits
fully on the card.

### Ollama vs vLLM

Both target the same card, and only one can practically hold it at a time on 12GB.

| | Ollama | vLLM |
|---|--------|------|
| Model handling | Swaps on demand, frees VRAM when idle | Pins one model in VRAM continuously |
| Best for | Interactive chat via Open WebUI | Batch/queued jobs needing throughput |
| VRAM overhead | Modest | Reserves a large paged-attention pool |

Ollama is the default for this box. vLLM is an occasional, deliberate guest for
batch workloads — bring it up for a specific job, then take it back down.
Running both concurrently on a single 12GB card will OOM.

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

- Confirm Ollama is genuinely GPU-backed by checking `nvidia-smi` *during* a generation, not at idle.
- Check whether Immich ML is actually using the RTX 3060 — it was an intended consumer of the card but its GPU allocation has not been verified.
- Confirm qBittorrent's VPN (WireGuard/ProtonVPN) is still active — not re-verified this pass.
- Confirm exact container membership within the `arr` and `releasarr` dockge stacks (this pass inferred membership from dataset folder names, not from reading the actual compose files).
- Re-verify NPM proxy host list for the full current subdomain mapping.

---

*Last Updated: 2026-08-16*
