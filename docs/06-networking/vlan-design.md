# VLAN Design and Architecture

## Overview

This document outlines the future network design with proper segmentation using VLANs (Virtual Local Area Networks). This architecture will be implemented in Phase 8 of the migration strategy after OPNsense deployment.

**Current State:** Single flat network (192.168.1.0/24)

**Future State:** Segmented network with 5 VLANs for security, performance, and organization

## VLAN Architecture

### VLAN Summary Table

| VLAN ID | Name | Subnet | Purpose | Gateway | DHCP |
|---------|------|--------|---------|---------|------|
| 10 | Management | 192.168.10.0/24 | Infrastructure management | 192.168.10.1 | Yes (limited) |
| 20 | Storage | 192.168.20.0/24 | iSCSI/NFS storage traffic | 192.168.20.1 | No (static only) |
| 30 | Services | 192.168.30.0/24 | VMs, containers, servers | 192.168.30.1 | Yes |
| 40 | IoT/Test | 192.168.40.0/24 | Untrusted devices, test VMs | 192.168.40.1 | Yes |
| 50 | LAN | 192.168.50.0/24 | User devices, workstations | 192.168.50.1 | Yes |

### Network Diagram

```
                    Internet
                       |
                  Frontier ONT
                       |
                  OPNsense VM
              [Router/Firewall]
               WAN: DHCP (public)
               LAN: vmbr1 (tagged)
                       |
              Managed Switch (VLAN-aware)
              [Trunk ports with tags]
                       |
        +-------+------+------+------+-------+
        |       |      |      |      |       |
      VLAN10  VLAN20 VLAN30 VLAN40 VLAN50   WiFi APs
       Mgmt   Storage Services Test   LAN   (multiple VLANs)
        |       |      |      |      |
     Proxmox TrueNAS  VMs   Test   Clients
     TrueNAS         k3s   Devices
     OPNsense        Pis
     (admin)
```

## VLAN 10: Management

### Purpose
Administrative access to infrastructure devices. Highly restricted, admin workstation only.

### Subnet Details
- **Network:** 192.168.10.0/24
- **Gateway:** 192.168.10.1 (OPNsense)
- **Broadcast:** 192.168.10.255
- **Usable IPs:** 192.168.10.2 - 192.168.10.254

### IP Assignments
- **192.168.10.1** - OPNsense (gateway)
- **192.168.10.2** - Pi-hole floating VIP (DNS HA)
- **192.168.10.10** - TrueNAS management interface
- **192.168.10.20** - Raspberry Pi 4 #1 (Pi-hole primary)
- **192.168.10.21** - Raspberry Pi 4 #2 (Pi-hole secondary)
- **192.168.10.50** - Proxmox node 1
- **192.168.10.51** - Proxmox node 2 (future)
- **192.168.10.100-199** - Reserved for additional infrastructure
- **192.168.10.200-254** - DHCP pool (admin devices)

### Devices on This VLAN
- Proxmox hypervisor management interface
- TrueNAS web UI and SSH
- OPNsense admin interface
- Raspberry Pi nodes (Pi-hole, monitoring)
- Admin workstation (for accessing management interfaces)
- Future: Managed switch web interface

### Security Rules
**Inbound (to Management VLAN):**
- Allow from admin workstation IP only
- Allow SSH (22) from admin workstation
- Allow HTTPS (443, 8006) from admin workstation
- Allow ICMP (ping) from all VLANs
- Deny all other traffic

**Outbound (from Management VLAN):**
- Allow to all VLANs (for management)
- Allow to Internet (for updates)

### Services
- **DNS:** Pi-hole (192.168.10.2 VIP)
- **NTP:** OPNsense
- **DHCP:** OPNsense (limited scope for admin devices)

### Why Management VLAN?
- Isolates critical infrastructure from user devices
- Prevents casual users from accessing admin interfaces
- Reduces attack surface (only admin workstation can access)
- Easier to audit (all management traffic in one VLAN)

## VLAN 20: Storage

### Purpose
Dedicated network for storage traffic (iSCSI, NFS). Isolated for performance and security.

### Subnet Details
- **Network:** 192.168.20.0/24
- **Gateway:** 192.168.20.1 (OPNsense, but rarely used)
- **Broadcast:** 192.168.20.255
- **Usable IPs:** 192.168.20.2 - 192.168.20.254

### IP Assignments
- **192.168.20.1** - OPNsense (gateway, for routing if needed)
- **192.168.20.10** - TrueNAS storage interface
- **192.168.20.50** - Proxmox node 1 storage interface
- **192.168.20.51** - Proxmox node 2 storage interface (future)
- **192.168.20.100-199** - Reserved for k3s nodes storage IPs
- **192.168.20.200-254** - Reserved for future storage expansion

### Devices on This VLAN
- TrueNAS storage network interface (separate from management)
- Proxmox storage interface (dedicated NIC or VLAN-tagged)
- k3s worker nodes (for mounting NFS persistent volumes)

### Security Rules
**Inbound (to Storage VLAN):**
- Allow iSCSI (3260) from Services VLAN (Proxmox, k3s)
- Allow NFS (2049, 111, various) from Services VLAN
- Allow ICMP (ping)
- Deny all other traffic (including from LAN and IoT VLANs)

**Outbound (from Storage VLAN):**
- Allow to Services VLAN (responses)
- Allow to Management VLAN (for admin access)
- Deny to Internet (storage should never need Internet)

### Configuration
- **MTU:** Jumbo frames (9000) for better throughput
- **No DHCP:** All static IPs (storage should never change)
- **No Internet Access:** Storage isolated from WAN

### Why Storage VLAN?
- Isolates high-bandwidth storage traffic from other networks
- Prevents storage protocols from being exposed to user devices
- Enables jumbo frames without affecting other VLANs
- Security: Only authorized devices can access storage
- Performance: Dedicated bandwidth for storage I/O

### Network Interface Requirements
**TrueNAS:**
- Option 1: Dual NIC (VLAN 10 for management, VLAN 20 for storage)
- Option 2: Single NIC with VLAN tagging (both VLANs on one interface)

**Proxmox:**
- Option 1: USB-to-2.5GbE adapter dedicated to storage VLAN
- Option 2: VLAN tagging on single NIC
- Recommended: Physical adapter for better performance

## VLAN 30: Services

### Purpose
VMs, containers, and server applications. The "production" environment for migrated services.

### Subnet Details
- **Network:** 192.168.30.0/24
- **Gateway:** 192.168.30.1 (OPNsense)
- **Broadcast:** 192.168.30.255
- **Usable IPs:** 192.168.30.2 - 192.168.30.254

### IP Assignments
- **192.168.30.1** - OPNsense (gateway)
- **192.168.30.10-49** - Static server IPs
  - 192.168.30.10 - Uptime Kuma VM
  - 192.168.30.11 - *arr stack VM
  - 192.168.30.12 - qBittorrent + VPN VM
  - 192.168.30.13 - n8n automation VM
  - 192.168.30.14 - OctoPrint VM
  - 192.168.30.15-49 - Reserved for additional VMs
- **192.168.30.50-99** - k3s cluster
  - 192.168.30.50 - k3s control plane
  - 192.168.30.51-59 - k3s worker VMs
  - 192.168.30.60-99 - k3s pod IP range (MetalLB)
- **192.168.30.100-254** - DHCP pool (temporary VMs, testing)

### Devices on This VLAN
- All Proxmox VMs (except OPNsense)
- Kubernetes pods (via MetalLB load balancer)
- Docker containers on VMs
- Future: Additional compute nodes

### Security Rules
**Inbound (to Services VLAN):**
- Allow from LAN VLAN (users accessing services)
- Allow from Management VLAN (admin access)
- Allow from IoT VLAN (limited, if needed)
- Deny from Storage VLAN (storage doesn't need to initiate to services)

**Outbound (from Services VLAN):**
- Allow to Storage VLAN (mount NFS, iSCSI)
- Allow to Management VLAN (for DNS, monitoring)
- Allow to Internet (updates, downloads)
- Allow to LAN VLAN (if services need to reach users)

### Services Running Here
- Uptime Kuma (monitoring)
- *arr stack (Sonarr, Radarr, etc.)
- qBittorrent (downloads)
- n8n (automation)
- Tracktor (package tracking)
- Kubernetes workloads
- Future: Additional migrated services

### Why Services VLAN?
- Separates servers from user devices
- Allows targeted firewall rules (e.g., block services from accessing user LAN)
- Easier to monitor all service traffic
- Can apply QoS policies specifically to services

## VLAN 40: IoT/Test

### Purpose
Untrusted devices (IoT) and test VMs. Internet-only access, isolated from other networks.

### Subnet Details
- **Network:** 192.168.40.0/24
- **Gateway:** 192.168.40.1 (OPNsense)
- **Broadcast:** 192.168.40.255
- **Usable IPs:** 192.168.40.2 - 192.168.40.254

### IP Assignments
- **192.168.40.1** - OPNsense (gateway)
- **192.168.40.10-99** - IoT devices (smart home, cameras, etc.)
- **192.168.40.100-254** - DHCP pool (test VMs, untrusted devices)

### Devices on This VLAN
- IoT devices (smart speakers, cameras, sensors)
- Test VMs (experimenting with malware, vulnerable software)
- Guest devices (visitors' phones/laptops if guest WiFi enabled)
- 3D printer (if considered untrusted)

### Security Rules
**Inbound (to IoT/Test VLAN):**
- Allow from Management VLAN (admin access for configuration)
- Allow from LAN VLAN (users controlling IoT devices via apps)
- Deny from all other VLANs

**Outbound (from IoT/Test VLAN):**
- Allow to Internet (IoT devices need cloud services)
- Allow to Management VLAN for DNS only (Pi-hole)
- Deny to all other VLANs (no access to storage, services, LAN)

### Why IoT/Test VLAN?
- IoT devices often have poor security (outdated firmware, weak passwords)
- Isolates potentially compromised devices
- Test VMs can't reach production services if compromised
- Guests can't access your files or servers
- Still allows IoT devices to function (Internet access for cloud services)

### Special Considerations
**If IoT needs to access Services:**
- Example: Smart speaker needs to play music from Jellyfin
- Create specific firewall rule allowing IoT → Jellyfin only
- Block everything else

**Test VMs:**
- Use this VLAN for security research, malware analysis, etc.
- Can safely break things without affecting other networks

## VLAN 50: LAN (User Network)

### Purpose
User devices, workstations, family members' phones/laptops. Main network for daily use.

### Subnet Details
- **Network:** 192.168.50.0/24
- **Gateway:** 192.168.50.1 (OPNsense)
- **Broadcast:** 192.168.50.255
- **Usable IPs:** 192.168.50.2 - 192.168.50.254

### IP Assignments
- **192.168.50.1** - OPNsense (gateway)
- **192.168.50.10-49** - Static IPs for trusted devices
  - 192.168.50.10 - Admin workstation
  - 192.168.50.11 - Desktop PC
  - 192.168.50.12 - Laptop
  - 192.168.50.13-49 - Reserved for family devices
- **192.168.50.50-254** - DHCP pool (phones, tablets, guests)

### Devices on This VLAN
- Desktop PC (Windows/Linux)
- Laptop
- Family members' phones, tablets, laptops
- Smart TVs (if trusted)
- Gaming consoles
- Work laptops (via WiFi)

### Security Rules
**Inbound (to LAN VLAN):**
- Allow from Management VLAN (for admin access if needed)
- Allow from Services VLAN (if services need to reach users, like notifications)
- Deny from IoT/Test VLAN
- Deny from Storage VLAN

**Outbound (from LAN VLAN):**
- Allow to Services VLAN (accessing Jellyfin, *arr web UIs, etc.)
- Allow to Management VLAN (accessing admin interfaces from admin workstation)
- Allow to IoT VLAN (controlling smart home devices)
- Allow to Internet
- Deny to Storage VLAN (no direct storage access)

### Services Accessed from LAN
- Jellyfin (via Services VLAN or TrueNAS if not migrated)
- Immich (via TrueNAS)
- *arr web UIs (via Services VLAN)
- Nginx Proxy Manager (accessing external URLs)
- Management interfaces (from admin workstation only)

### Why LAN VLAN?
- Separates user devices from infrastructure
- Allows family to safely use network without risk to servers
- Can apply content filtering/parental controls if desired
- Guest WiFi can be on same VLAN (or separate guest VLAN)

## Inter-VLAN Routing and Firewall Rules

### Routing
- **OPNsense** acts as router between VLANs
- All inter-VLAN traffic passes through OPNsense firewall
- Default: Deny all, explicit allow rules only

### Firewall Rule Philosophy
1. **Default Deny:** Block everything, then allow specific traffic
2. **Least Privilege:** Only allow minimum necessary access
3. **Logging:** Log denied traffic to detect issues or attacks
4. **Review Regularly:** Audit rules monthly

### Common Rule Examples

**Management → All VLANs:**
```
Allow: Source=Management VLAN, Destination=Any, Ports=Any
Reason: Admin needs access to everything
```

**Services → Storage:**
```
Allow: Source=Services VLAN, Destination=Storage VLAN, Ports=NFS(2049), iSCSI(3260)
Reason: VMs need to mount storage
```

**LAN → Services:**
```
Allow: Source=LAN VLAN, Destination=Services VLAN, Ports=HTTP(80), HTTPS(443)
Reason: Users access web UIs
```

**IoT → Internet:**
```
Allow: Source=IoT VLAN, Destination=WAN, Ports=Any
Deny: Source=IoT VLAN, Destination=RFC1918 (all private IPs)
Reason: IoT can reach Internet but not local networks
```

### NAT (Network Address Translation)
- All VLANs use NAT to access Internet through OPNsense
- OPNsense WAN interface has public IP (from ISP)
- Internal IPs (192.168.x.x) translated to public IP

## WiFi SSID to VLAN Mapping

### Planned WiFi SSIDs

**HomeSSID (Main Network)**
- **VLAN:** 50 (LAN)
- **Security:** WPA3 or WPA2/WPA3
- **Purpose:** Family devices
- **DHCP:** Yes

**HomeSSID-IoT**
- **VLAN:** 40 (IoT/Test)
- **Security:** WPA2 (some IoT devices don't support WPA3)
- **Purpose:** Smart home devices
- **DHCP:** Yes
- **Isolation:** Enabled (devices can't see each other)

**HomeSSID-Admin** (optional, can use Ethernet)
- **VLAN:** 10 (Management)
- **Security:** WPA3
- **Purpose:** Admin devices only
- **DHCP:** Limited (admin devices only)

**HomeSSID-Guest** (optional)
- **VLAN:** 40 (IoT/Test) or separate VLAN
- **Security:** WPA2, shared password or captive portal
- **Purpose:** Visitors
- **DHCP:** Yes
- **Internet only:** No access to any internal VLANs

### WiFi AP Configuration
- Each AP broadcasts multiple SSIDs
- Each SSID tagged with appropriate VLAN ID
- APs connected to switch via trunk port (all VLANs tagged)
- APs themselves on Management VLAN for admin access

## DNS Configuration

### Pi-hole on Management VLAN
- **Primary:** 192.168.10.20 (Pi 4 #1)
- **Secondary:** 192.168.10.21 (Pi 4 #2)
- **Floating VIP:** 192.168.10.2 (HA virtual IP)

### DNS for Each VLAN
**Option 1: All VLANs use Pi-hole directly**
- DHCP hands out 192.168.10.2 (Pi-hole VIP) as DNS
- Firewall allows all VLANs → Pi-hole on port 53 (DNS)

**Option 2: OPNsense DNS forwarder**
- DHCP hands out VLAN gateway (192.168.X.1) as DNS
- OPNsense forwards to Pi-hole
- Adds flexibility, easier to change DNS later

**Recommended:** Option 1 (direct to Pi-hole)

### Local DNS Records
Pi-hole manages internal DNS:
- `truenas.local` → 192.168.10.10 (management), 192.168.20.10 (storage)
- `proxmox.local` → 192.168.10.50
- `jellyfin.local` → TrueNAS or VM IP
- etc.

## DHCP Configuration

### DHCP Servers
**OPNsense DHCP service runs separate pools for each VLAN:**

**Management VLAN (10):**
- Scope: 192.168.10.200-254
- Lease: 24 hours
- Options: DNS=192.168.10.2, Gateway=192.168.10.1

**Storage VLAN (20):**
- No DHCP (all static)

**Services VLAN (30):**
- Scope: 192.168.30.100-254
- Lease: 12 hours (VMs can change)
- Options: DNS=192.168.10.2, Gateway=192.168.30.1

**IoT/Test VLAN (40):**
- Scope: 192.168.40.100-254
- Lease: 24 hours
- Options: DNS=192.168.10.2, Gateway=192.168.40.1

**LAN VLAN (50):**
- Scope: 192.168.50.50-254
- Lease: 24 hours
- Options: DNS=192.168.10.2, Gateway=192.168.50.1

### DHCP Reservations
For devices that need consistent IPs but don't support static:
- Bind MAC address to specific IP in DHCP scope
- Managed via OPNsense web UI

## Switch Configuration

### Port Assignments

**Trunk Ports (All VLANs Tagged):**
- Port 1: OPNsense LAN interface
- Port 2: WiFi AP #1
- Port 3: WiFi AP #2 (if multiple APs)

**Access Ports (Single VLAN, Untagged):**
- Port 4: TrueNAS (VLAN 10 untagged, VLAN 20 tagged)
- Port 5: Proxmox (VLAN 10 untagged, VLAN 20 tagged)
- Port 6: Desktop PC (VLAN 50 untagged)
- Port 7: Available (VLAN 50 default)
- Port 8: Available (VLAN 50 default)

**Hybrid Configuration for TrueNAS/Proxmox:**
- Native VLAN: 10 (Management, untagged)
- Tagged VLANs: 20 (Storage), 30 (Services if needed)
- Allows single NIC to handle multiple VLANs

### VLAN Configuration Steps
1. Create VLANs 10, 20, 30, 40, 50 on switch
2. Assign names (Management, Storage, etc.)
3. Configure trunk ports (all VLANs allowed)
4. Configure access ports (specific VLAN per port)
5. Set native VLAN for each port
6. Test connectivity between VLANs (should fail until OPNsense rules added)

## Migration from Flat Network to VLANs

### Phase 1: Parallel Operation
- Keep existing flat network (Deco) running
- Deploy OPNsense and managed switch
- Configure VLANs but don't move devices yet
- Test VLAN connectivity in isolation

### Phase 2: Infrastructure First
- Move TrueNAS to VLAN 10 (management) + VLAN 20 (storage)
- Move Proxmox to VLAN 10 + VLAN 20
- Move admin workstation to VLAN 10 (or VLAN 50 with access rules)
- Verify management access works

### Phase 3: Services
- Move VMs to VLAN 30 (update Proxmox network bridges)
- Update firewall rules to allow LAN → Services
- Verify family can still access Jellyfin, etc.

### Phase 4: User Devices
- Move desktop PC to VLAN 50
- Reconfigure WiFi SSIDs with VLAN tags
- Users reconnect to WiFi (should be transparent)

### Phase 5: IoT/Test
- Move IoT devices to VLAN 40
- Test that they still reach Internet
- Verify they cannot access other VLANs

### Phase 6: Decommission Flat Network
- Turn off Deco router functionality (or remove)
- Use Deco units as WiFi APs only (if keeping)
- Or replace with proper managed APs

## Security Considerations

### Principle of Least Privilege
- Only allow traffic that's needed
- Block everything else
- Review and tighten rules over time

### Attack Scenarios and Mitigations

**Compromised IoT Device:**
- Attacker gains control of smart camera
- **Mitigation:** IoT VLAN blocks access to other networks
- Attacker can only reach Internet, not your files

**Compromised VM:**
- Malware on test VM in Services VLAN
- **Mitigation:** Firewall prevents lateral movement
- VM cannot access Management or Storage VLANs

**Compromised User Device:**
- Malware on family member's laptop
- **Mitigation:** LAN VLAN cannot access Storage directly
- Attacker can access Services (like Jellyfin) but not infrastructure

### Defense in Depth
1. **VLAN Segmentation:** Network isolation
2. **Firewall Rules:** Traffic filtering
3. **IDS/IPS:** Intrusion detection (OPNsense Suricata)
4. **Strong Passwords:** All admin interfaces
5. **Regular Updates:** Keep firmware/software current
6. **Monitoring:** Log review and alerting

## Performance Considerations

### Bandwidth Allocation
- **Storage VLAN:** Highest priority (for iSCSI/NFS)
- **Services VLAN:** Medium priority
- **LAN VLAN:** Medium priority (Jellyfin streaming important)
- **IoT/Test VLAN:** Lowest priority

### QoS (Quality of Service)
**On OPNsense:**
- Prioritize Storage VLAN traffic
- Prioritize Jellyfin streaming (port 8096)
- Deprioritize downloads (qBittorrent)

**On Managed Switch:**
- Configure port priority (Storage ports highest)
- Enable QoS for VoIP or gaming if needed

### MTU (Maximum Transmission Unit)
- **Storage VLAN:** Jumbo frames (MTU 9000)
- **All other VLANs:** Standard (MTU 1500)
- Requires all devices on Storage VLAN to support jumbo frames

## Monitoring and Troubleshooting

### Tools
- **OPNsense Firewall Logs:** See blocked/allowed traffic
- **OPNsense Traffic Graphs:** Bandwidth usage per VLAN
- **Suricata IDS:** Detect suspicious traffic
- **ntopng:** Deep packet inspection and analysis
- **Grafana + Prometheus:** Metrics and alerting

### Common Issues

**Can't access device after VLAN migration:**
- Check firewall rules (likely blocked)
- Verify device is on correct VLAN
- Check DHCP/static IP configuration

**Slow performance after VLANs:**
- Check if routing through OPNsense is bottleneck
- Verify switch is handling VLANs correctly
- Look for excessive broadcast traffic

**Inter-VLAN routing not working:**
- Verify OPNsense has interfaces for all VLANs
- Check that IP forwarding is enabled
- Review firewall rules (default deny)

## Documentation and Maintenance

### Keep Updated
- Document all VLAN changes in Git
- Update network diagrams when devices move
- Record all firewall rule changes with reasons
- Maintain IP address allocation spreadsheet

### Regular Reviews
- **Monthly:** Review firewall logs for denied traffic
- **Quarterly:** Audit firewall rules, remove unused rules
- **Annually:** Review VLAN design, adjust if needed

## Next Steps

1. Complete Phase 1-7 of migration (VMs, k8s, services)
2. Research and purchase managed switch
3. Test OPNsense in VM on Proxmox
4. Design detailed firewall rules for each VLAN
5. Plan cutover weekend for network migration
6. Document rollback procedure

---

*Last Updated: 2025-01-26*