# Raspberry Pi Hardware

## Overview

Currently available Raspberry Pi nodes for homelab deployment:
- 2x Raspberry Pi 4 Model B
- 1x Raspberry Pi Zero 2 W

These devices provide low-power, always-on compute for edge services, high availability, and distributed systems learning.

## Hardware Specifications

### Raspberry Pi 4 Model B (x2)

**Processor:**
- **SoC:** Broadcom BCM2711
- **CPU:** Quad-core Cortex-A72 (ARM v8) 64-bit @ 1.5GHz
- **Architecture:** ARMv8-A (64-bit)

**Memory:**
- **RAM:** Unknown capacity (likely 2GB, 4GB, or 8GB variants)
- **Note:** Check physical boards for RAM amount (printed on board)

**Storage:**
- **MicroSD Card Slot:** Primary storage
- **USB Boot:** Supports booting from USB SSD (recommended for reliability)
- **Recommended:** 32GB+ MicroSD or USB SSD for OS + services

**Networking:**
- **Ethernet:** Gigabit Ethernet (1000 Mbps, full duplex)
- **WiFi:** 2.4 GHz and 5.0 GHz IEEE 802.11ac wireless
- **Bluetooth:** Bluetooth 5.0, BLE

**USB Ports:**
- 2x USB 3.0 ports
- 2x USB 2.0 ports

**Video/Display:**
- 2x micro-HDMI ports (up to 4K 60Hz)
- Not relevant for headless server use

**GPIO:**
- 40-pin GPIO header
- Useful for sensors, displays, or hardware projects

**Power:**
- **Input:** USB-C, 5V/3A (15W)
- **Typical Consumption:** 2-4W idle, 6-8W under load
- **Power Supply:** Official Raspberry Pi power supply recommended

**Dimensions:**
- 85mm x 56mm x 17mm

### Raspberry Pi Zero 2 W (x1)

**Processor:**
- **SoC:** Broadcom BCM2710A1
- **CPU:** Quad-core Cortex-A53 (ARM v8) 64-bit @ 1GHz
- **Architecture:** ARMv8-A (64-bit)

**Memory:**
- **RAM:** 512MB LPDDR2

**Storage:**
- **MicroSD Card Slot:** Primary storage
- **No USB boot support** (must use MicroSD)
- **Recommended:** 16GB+ MicroSD

**Networking:**
- **WiFi:** 2.4 GHz IEEE 802.11 b/g/n wireless
- **Bluetooth:** Bluetooth 4.2, BLE
- **No Ethernet:** WiFi only (can add USB Ethernet adapter)

**USB:**
- 1x micro-USB OTG port (requires adapter for standard USB)
- 1x micro-USB power port

**GPIO:**
- 40-pin GPIO header (same as Pi 4, but unpopulated - requires soldering)

**Power:**
- **Input:** Micro-USB, 5V/2.5A
- **Typical Consumption:** 0.4-1W idle, 1.5-2W under load
- **Extremely power efficient**

**Dimensions:**
- 65mm x 30mm x 5mm (much smaller than Pi 4)

## Performance Comparison

| Feature | Raspberry Pi 4 | Raspberry Pi Zero 2 W |
|---------|----------------|------------------------|
| **CPU Cores** | 4x Cortex-A72 @ 1.5GHz | 4x Cortex-A53 @ 1GHz |
| **RAM** | 2GB/4GB/8GB | 512MB |
| **Ethernet** | Gigabit | None (WiFi only) |
| **WiFi** | 2.4GHz + 5GHz | 2.4GHz only |
| **USB** | 4x ports (2x USB 3.0) | 1x micro-USB OTG |
| **Power** | ~6W typical | ~1W typical |
| **Use Case** | Services, DNS, monitoring | Sensors, lightweight tasks |
| **Storage** | MicroSD or USB SSD | MicroSD only |

## Planned Deployments

### Raspberry Pi 4 #1: Primary Services Node
**Intended Services:**
- **Pi-hole:** Primary DNS server with ad blocking
- **Monitoring Agent:** Prometheus node exporter, telegraf
- **Lightweight Services:** Small containers or services that need high availability

**Resource Allocation:**
- Pi-hole: ~100-200MB RAM
- Monitoring: ~50-100MB RAM
- OS overhead: ~200-300MB RAM
- Remaining: For additional lightweight services

**Storage Requirements:**
- OS: ~4-8GB
- Pi-hole database: 1-2GB (grows over time)
- Logs: ~1-2GB
- Total: 16GB+ MicroSD or USB SSD

**Network:**
- Wired Gigabit Ethernet (preferred for DNS reliability)
- Static IP: 192.168.1.20 (or 192.168.10.20 after VLAN migration)

### Raspberry Pi 4 #2: Backup/Secondary Node
**Intended Services:**
- **Pi-hole:** Secondary DNS (HA pair with Pi #1)
- **Backup Services:** Sync configurations from primary systems
- **Test Platform:** Kubernetes edge worker (k3s agent)

**High Availability with Pi #1:**
- Both Pis run Pi-hole with synchronized configuration
- Use keepalived for floating VIP (virtual IP)
- If one Pi fails, the other takes over DNS automatically
- Clients configure both IPs as DNS servers

**Network:**
- Wired Gigabit Ethernet
- Static IP: 192.168.1.21 (or 192.168.10.21 after VLAN migration)
- Floating VIP: 192.168.1.2 (shared between both Pis)

### Raspberry Pi Zero 2 W: Edge/Sensor Node
**Intended Uses:**
- **Lightweight Monitoring:** Temperature sensors, network quality monitoring
- **Edge Computing:** Process data locally before sending to main systems
- **Learning Platform:** GPIO projects, sensor integration
- **Always-On Utility:** Extremely low power for 24/7 operation

**Limitations:**
- Only 512MB RAM (very limited)
- WiFi only (no Ethernet without adapter)
- Cannot run heavy services (Docker may struggle)
- Best for single-purpose, lightweight tasks

**Recommended OS:**
- Raspberry Pi OS Lite (no desktop, minimal footprint)
- DietPi (even lighter than Pi OS)

**Network:**
- WiFi 2.4GHz (acceptable for low-bandwidth tasks)
- Static IP: 192.168.1.22

## Operating System Options

### Raspberry Pi OS (Recommended for Pi-hole)
**Pros:**
- Official OS, best hardware support
- Well-documented, large community
- Debian-based (familiar for Linux learning)
- Lite version available (no desktop)

**Cons:**
- 32-bit by default (64-bit available but newer)
- Some bloat compared to minimal distros

**Use Case:** Pi-hole, general-purpose services

### Ubuntu Server (Recommended for k3s)
**Pros:**
- Official 64-bit ARM support
- LTS versions (long-term support)
- Cloud-init for automation
- Great for Kubernetes/containers

**Cons:**
- Slightly heavier than Pi OS
- May require more RAM

**Use Case:** Kubernetes workers, containerized services

### DietPi (Recommended for Pi Zero 2 W)
**Pros:**
- Extremely lightweight
- Pre-configured software options (easy Pi-hole install)
- Optimized for Pi hardware
- Fast boot times

**Cons:**
- Smaller community than Pi OS or Ubuntu
- Less documentation for troubleshooting

**Use Case:** Resource-constrained deployments (Pi Zero 2 W)

### Other Options
- **Alpine Linux:** Ultra-lightweight, Docker-focused
- **Armbian:** Alternative to Pi OS with more customization
- **k3OS:** Purpose-built for k3s (deprecated but still usable)

## Storage Recommendations

### MicroSD Cards
**For Pi 4 (if not using USB):**
- **Minimum:** 16GB, Class 10, A1 rating
- **Recommended:** 32GB+, UHS-I U3, A2 rating
- **Brands:** SanDisk Extreme, Samsung EVO Plus

**For Pi Zero 2 W:**
- **Minimum:** 16GB, Class 10
- **Recommended:** 32GB, UHS-I U1

**Important:**
- MicroSD cards wear out with heavy writes (logging, databases)
- Consider USB SSD for Pi 4 if running databases or logs

### USB SSD Boot (Pi 4 Only)
**Benefits:**
- Much faster than MicroSD (10-20x improvement)
- More reliable (SSDs handle writes better)
- Longer lifespan for database/log-heavy workloads
- Same or lower power consumption

**Recommended:**
- Small USB 3.0 SSD (128GB or 256GB)
- Brands: Samsung T7, Crucial X8, SanDisk Extreme

**Setup:**
- Update Pi 4 bootloader to support USB boot
- Flash OS to USB SSD instead of MicroSD
- Boot from USB (no MicroSD needed)

## Power Supply Requirements

### Raspberry Pi 4
- **Official:** 5V/3A USB-C power supply (~$8)
- **Total Power:** 15W maximum
- **Actual Usage:** 2-4W idle, 6-8W under load
- **PoE Option:** PoE HAT available (powers Pi via Ethernet, requires PoE switch)

### Raspberry Pi Zero 2 W
- **Official:** 5V/2.5A micro-USB power supply
- **Total Power:** 12.5W maximum
- **Actual Usage:** 0.4-1W idle, 1.5-2W under load
- **Can power from USB port** (Pi 4 USB port can power Zero 2 W)

### Power Considerations
- Use quality power supplies (cheap adapters cause instability)
- Consider UPS for critical services (Pi-hole)
- All 3 Pis combined: ~15W typical (~$1.50/month electricity)

## Network Configuration

### Pi 4 #1 (Primary Services)
- **Connection:** Wired Ethernet (Gigabit)
- **IP:** 192.168.1.20 (static)
- **Hostname:** pi-services-01 or pi-dns-01
- **Services:** Pi-hole (primary), monitoring

### Pi 4 #2 (Backup/Secondary)
- **Connection:** Wired Ethernet (Gigabit)
- **IP:** 192.168.1.21 (static)
- **Hostname:** pi-services-02 or pi-dns-02
- **Services:** Pi-hole (secondary), backup

### Pi Zero 2 W (Edge Node)
- **Connection:** WiFi 2.4GHz
- **IP:** 192.168.1.22 (static)
- **Hostname:** pi-edge-01 or pi-sensor-01
- **Services:** Monitoring, sensors, edge processing

### After VLAN Migration
- **VLAN 10 (Management):** Pi-hole nodes for maximum uptime
- **VLAN 30 (Services):** If running other services
- **Floating VIP:** 192.168.10.2 (Pi-hole HA virtual IP)

## Use Case: Pi-hole High Availability

### Architecture
```
Clients
   |
   +---> DNS Query (192.168.1.2 VIP)
   |
   +---> Pi 4 #1 (192.168.1.20) [MASTER]
   |       |
   |       +---> Pi-hole DNS
   |       +---> Keepalived (manages VIP)
   |
   +---> Pi 4 #2 (192.168.1.21) [BACKUP]
           |
           +---> Pi-hole DNS (synced config)
           +---> Keepalived (monitors Pi #1)
```

### How It Works
1. Both Pis run Pi-hole with identical configuration
2. Keepalived runs on both, monitoring each other
3. VIP (192.168.1.2) normally points to Pi #1
4. If Pi #1 fails, VIP automatically moves to Pi #2
5. Clients always use VIP as DNS server
6. No manual intervention needed for failover

### Gravity Sync
- Tool to synchronize Pi-hole configurations between nodes
- Automatically syncs blocklists, whitelist, settings
- Runs periodically (e.g., every hour)
- Ensures both Pis have identical DNS responses

## Use Case: Kubernetes Edge Workers

### Why Pi for k3s?
- Learn distributed systems on cheap hardware
- Simulate multi-node cluster without buying servers
- ARM architecture practice (same as cloud ARM instances)
- Always-on workers without high power cost

### Deployment Pattern
```
Proxmox VM (k3s server/control plane)
   |
   +---> API Server, Scheduler, Controller
   |
   +---> k3s Agent (Pi 4 #1) [ARM worker]
   |       |
   |       +---> Runs ARM-compatible pods
   |       +---> Lightweight workloads
   |
   +---> k3s Agent (Pi 4 #2) [ARM worker]
           |
           +---> Runs ARM-compatible pods
           +---> High availability for edge services
```

### Limitations
- Must use ARM-compatible container images
- Limited RAM (2-8GB vs. VM with more)
- Best for lightweight workloads (monitoring agents, simple web apps)

## Maintenance & Management

### Initial Setup Checklist
- [ ] Flash OS to MicroSD/USB
- [ ] Enable SSH before first boot
- [ ] Set static IP (via router DHCP or /etc/network/interfaces)
- [ ] Set hostname
- [ ] Update system: `sudo apt update && sudo apt upgrade`
- [ ] Install basic tools: `sudo apt install vim git htop`
- [ ] Configure time zone: `sudo timedatectl set-timezone America/Chicago`
- [ ] Disable swap if using MicroSD (reduce writes)
- [ ] Set up SSH keys for passwordless login

### Monitoring
- **CPU Temperature:** `vcgencmd measure_temp` (should be <70°C)
- **CPU Speed:** `vcgencmd measure_clock arm`
- **Voltage:** `vcgencmd measure_volts` (should be ~5V, >4.8V)
- **Throttling:** `vcgencmd get_throttled` (0x0 = no throttling)

### Common Issues
**Under-voltage warnings:**
- Use official power supply or high-quality 3A USB-C
- Check cable quality (some cables have high resistance)
- Undervoltage causes instability and SD card corruption

**SD card corruption:**
- Use quality cards (SanDisk, Samsung)
- Enable read-only root filesystem for critical services
- Consider USB SSD boot for reliability
- Regular backups

**WiFi dropping (Pi Zero 2 W):**
- Weak signal (Pi Zero has smaller antenna)
- Add USB WiFi dongle for better reception
- Or run long Ethernet cable with USB adapter

### Backup Strategy
- **SD card image backup:** Use `dd` or Win32DiskImager to clone entire card
- **Configuration backup:** Git repository for /etc configs
- **Pi-hole backup:** Built-in teleporter feature exports settings
- **Automated backups:** Cron job to rsync to TrueNAS

### Update Schedule
- **Weekly:** Check for OS updates, reboot if kernel updated
- **Monthly:** Review logs, check disk space
- **Quarterly:** Full backup, test restore procedure

## Shopping List (If Expanding)

### Essential
- MicroSD cards: $10-15 each (32GB SanDisk/Samsung)
- Official power supplies: $8 each
- Ethernet cables (if not already available): $5-10

### Recommended
- USB 3.0 SSD (128GB): $20-30 (for Pi 4 USB boot)
- Heatsinks/fans: $5-10 (for better cooling under load)
- Cases: $5-15 each (protect hardware, improve cooling)

### Optional
- PoE HAT for Pi 4: $20-25 (if using PoE switch)
- USB Ethernet adapter for Pi Zero 2 W: $10-15
- GPIO accessories (sensors, displays): Varies

## Future Expansion Ideas

### Add More Pi 4 Nodes
- Build 4-node ARM k3s cluster
- Distributed storage with Longhorn or Rook
- Learn Kubernetes HA patterns
- Cost: ~$150-200 for 2 more Pi 4 (4GB models)

### Pi Zero Cluster
- PicoCluster or custom rack
- 10+ Pi Zeros for massive parallel learning
- Simulate large distributed systems
- Very low power cost
- Cost: ~$15 per Pi Zero 2 W

### Specialized Use Cases
- **Home automation:** Home Assistant on Pi
- **Network monitoring:** LibreNMS, Zabbix
- **VPN gateway:** Dedicated WireGuard server
- **Print server:** CUPS for network printing
- **NAS:** OpenMediaVault (though TrueNAS better)

## Learning Objectives

Using Raspberry Pis enables learning:
1. **ARM architecture:** Different from x86, common in cloud/mobile
2. **Distributed systems:** Multi-node clusters on a budget
3. **High availability:** Failover, redundancy, keepalived
4. **Edge computing:** Process data close to source
5. **Low-power systems:** Optimize for resource constraints
6. **GPIO programming:** Hardware interfacing (if desired)

## Documentation Standards

### Raspberry Pi Documentation
- Document MAC addresses (for DHCP reservations)
- Record SD card serial numbers (for replacement tracking)
- Note power supply voltage/amperage
- Track installed software and configurations
- Keep backup images with version/date

### Naming Convention
- **Hostname:** `pi-[purpose]-[number]`
  - Examples: `pi-dns-01`, `pi-dns-02`, `pi-edge-01`
- **IP:** Sequential in 192.168.1.20-29 range
- **DNS:** Add A records in Pi-hole for local resolution

---

*Last Updated: 2025-01-26*