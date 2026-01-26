# Proxmox Networking Setup

## Overview

This guide covers Proxmox network configuration for both current single-subnet environment and future VLAN-segmented network.

**Current Phase:** Single flat network (192.168.1.0/24)
**Future Phase:** VLAN-aware networking with multiple virtual bridges

## Proxmox Network Concepts

### Linux Bridges (vmbr)
- Virtual network switches created by Proxmox
- VMs connect to bridges, bridges connect to physical NICs
- Default: `vmbr0` created during installation
- Can create multiple bridges for different purposes

### Physical Interfaces
- `eno1`, `eth0`, `enp0s1` (names vary by hardware)
- Dell 3080 Micro: Typically `eno1` or similar
- Check with: `ip addr` or in Proxmox web UI

### VLAN Tagging (802.1Q)
- Single physical NIC can carry multiple VLANs
- Tagged packets include VLAN ID
- Proxmox can create VLAN-aware bridges
- Allows VMs to be on different VLANs using one NIC

### Bond (Link Aggregation)
- Combine multiple NICs for redundancy or bandwidth
- Not applicable with single NIC on Dell 3080 Micro
- Could add USB-to-Ethernet adapter for bonding in future

## Current Network Configuration (Phase 1)

### Physical Interface
- **Interface Name:** eno1 (check with `ip addr`)
- **Speed:** 1 Gigabit Ethernet
- **Connection:** To YuanLey switch
- **IP:** 192.168.1.50/24 (static recommended)

### Default Bridge: vmbr0
Created automatically during Proxmox installation.

**Configuration:**
```
auto vmbr0
iface vmbr0 inet static
    address 192.168.1.50/24
    gateway 192.168.1.1
    bridge-ports eno1
    bridge-stp off
    bridge-fd 0
```

**Explanation:**
- `vmbr0`: Bridge name (virtual switch)
- `inet static`: Static IP configuration
- `address`: Proxmox management IP
- `gateway`: Router IP (Deco)
- `bridge-ports eno1`: Physical NIC connected to bridge
- `bridge-stp off`: Spanning Tree Protocol disabled (not needed)
- `bridge-fd 0`: Forward delay set to 0 (faster startup)

### Accessing Configuration Files

**Via Web UI:**
- Navigate to: Datacenter → Node (pve) → System → Network

**Via CLI:**
```bash
# View network config
cat /etc/network/interfaces

# Edit network config
nano /etc/network/interfaces

# Apply changes (be careful, can lose connectivity!)
ifreload -a

# Or reboot to apply
reboot
```

### Setting Static IP

**Option 1: During Installation**
- Set static IP when installing Proxmox

**Option 2: After Installation (Web UI)**
1. Login to Proxmox web UI
2. Go to: Node → System → Network
3. Select `vmbr0` → Edit
4. Change from DHCP to Static
5. Set IP: 192.168.1.50
6. Set Gateway: 192.168.1.1
7. Set Netmask: 255.255.255.0 or /24
8. Apply Configuration (or reboot)

**Option 3: After Installation (CLI)**
```bash
# Edit network config
nano /etc/network/interfaces

# Change this:
iface vmbr0 inet dhcp

# To this:
iface vmbr0 inet static
    address 192.168.1.50/24
    gateway 192.168.1.1

# Apply
ifreload -a
```

### DNS Configuration
```bash
# Edit resolv.conf
nano /etc/resolv.conf

# Add DNS servers
nameserver 192.168.1.1
nameserver 8.8.8.8
nameserver 8.8.4.4
```

Or configure via Web UI: Node → System → DNS

## VM Networking (Current Phase)

### Attaching VMs to vmbr0
When creating a VM:
1. Hardware → Add → Network Device
2. Bridge: vmbr0
3. Model: VirtIO (paravirtualized, best performance)
4. VLAN Tag: Leave blank (no VLANs yet)
5. Firewall: Enable if desired

**Result:** VM gets IP on 192.168.1.0/24 network via DHCP or static config inside VM.

### VM Network Configuration (Inside Guest OS)

**Ubuntu/Debian (Netplan):**
```yaml
# /etc/netplan/00-installer-config.yaml
network:
  version: 2
  ethernets:
    ens18:  # Interface name (may vary)
      dhcp4: true
      # Or for static:
      # addresses:
      #   - 192.168.1.100/24
      # gateway4: 192.168.1.1
      # nameservers:
      #   addresses: [192.168.1.1, 8.8.8.8]
```

Apply with: `sudo netplan apply`

**Ubuntu/Debian (ifupdown, older):**
```bash
# /etc/network/interfaces
auto ens18
iface ens18 inet dhcp

# Or static:
# iface ens18 inet static
#     address 192.168.1.100
#     netmask 255.255.255.0
#     gateway 192.168.1.1
#     dns-nameservers 192.168.1.1 8.8.8.8
```

**CentOS/Rocky Linux:**
```bash
# /etc/sysconfig/network-scripts/ifcfg-ens18
TYPE=Ethernet
BOOTPROTO=dhcp
NAME=ens18
DEVICE=ens18
ONBOOT=yes

# Or static:
# BOOTPROTO=static
# IPADDR=192.168.1.100
# NETMASK=255.255.255.0
# GATEWAY=192.168.1.1
# DNS1=192.168.1.1
# DNS2=8.8.8.8
```

Restart network: `sudo systemctl restart NetworkManager`

### Verifying VM Connectivity
```bash
# From inside VM
ip addr show  # Check IP assigned
ping 192.168.1.1  # Ping gateway
ping 8.8.8.8  # Ping Internet
ping google.com  # Test DNS
```

## Future Network Configuration (Phase 2: VLANs)

### Physical Interface Limitations
Dell 3080 Micro has only one Gigabit Ethernet port. Options for multiple VLANs:

**Option 1: VLAN Tagging (Recommended)**
- Single NIC carries multiple VLANs using 802.1Q tags
- Managed switch must support VLAN tagging
- Proxmox creates VLAN-aware bridge
- No additional hardware needed

**Option 2: USB-to-Ethernet Adapter**
- Add second network interface via USB 3.0
- One NIC for Management (VLAN 10)
- Second NIC for Storage (VLAN 20)
- Better performance than VLAN tagging
- Cost: ~$30 for 2.5GbE USB adapter

**Option 3: Dual Setup (Recommended for Storage)**
- Management/Services: VLAN tagging on built-in NIC
- Storage: Dedicated USB 2.5GbE adapter for VLAN 20
- Best of both worlds

### Creating VLAN-Aware Bridge

**Method 1: Single VLAN-Aware Bridge (Flexible)**

Edit `/etc/network/interfaces`:
```
# Physical interface (no IP, just up)
auto eno1
iface eno1 inet manual

# VLAN-aware bridge
auto vmbr0
iface vmbr0 inet manual
    bridge-ports eno1
    bridge-stp off
    bridge-fd 0
    bridge-vlan-aware yes
    bridge-vids 10 20 30 40 50

# Management VLAN interface (for Proxmox host)
auto vmbr0.10
iface vmbr0.10 inet static
    address 192.168.10.50/24
    gateway 192.168.10.1
```

**Explanation:**
- `eno1`: Physical NIC, no IP (just a carrier)
- `vmbr0`: VLAN-aware bridge
- `bridge-vlan-aware yes`: Enable VLAN support
- `bridge-vids 10 20 30 40 50`: Allowed VLANs
- `vmbr0.10`: Management VLAN interface for Proxmox host

**Attaching VMs to VLANs:**
- VM on VLAN 30: Set VLAN Tag to 30 when adding network device
- VM gets IP from VLAN 30 subnet (192.168.30.x)

**Method 2: Separate Bridges per VLAN (Less Flexible)**

```
auto eno1
iface eno1 inet manual

# Management VLAN 10
auto vmbr0
iface vmbr0 inet static
    address 192.168.10.50/24
    gateway 192.168.10.1
    bridge-ports eno1.10
    bridge-stp off
    bridge-fd 0

# Services VLAN 30
auto vmbr1
iface vmbr1 inet manual
    bridge-ports eno1.30
    bridge-stp off
    bridge-fd 0

# (Repeat for other VLANs)
```

**Attaching VMs:**
- Management VM: Connect to vmbr0 (no VLAN tag needed)
- Services VM: Connect to vmbr1 (no VLAN tag needed)

**Comparison:**
- **VLAN-Aware Bridge:** More flexible, fewer bridges, requires VLAN tags on VMs
- **Separate Bridges:** Clearer separation, no VLAN tags on VMs, more configuration

**Recommended:** VLAN-aware bridge (Method 1) for flexibility

### Adding USB-to-Ethernet for Storage

**After connecting USB adapter:**

1. Identify new interface:
```bash
ip addr
# Look for new interface: eth1, enx... (MAC-based name)
```

2. Add to network config:
```
# USB Ethernet (dedicated to Storage VLAN)
auto eth1
iface eth1 inet manual

# Storage bridge
auto vmbr1
iface vmbr1 inet static
    address 192.168.20.50/24
    bridge-ports eth1
    bridge-stp off
    bridge-fd 0
    mtu 9000  # Jumbo frames for storage
```

3. Configure TrueNAS storage interface on VLAN 20
4. Mount NFS/iSCSI from Proxmox over vmbr1 (Storage VLAN)

**Benefits:**
- Dedicated bandwidth for storage traffic
- No contention with VM network traffic
- Can enable jumbo frames without affecting other VLANs

### Network Configuration Example (Full VLAN Setup)

**Scenario:** Single NIC with VLAN tagging + USB adapter for storage

```
# /etc/network/interfaces

# Physical NICs
auto eno1
iface eno1 inet manual

auto eth1  # USB adapter
iface eth1 inet manual

# VLAN-aware bridge for Management/Services
auto vmbr0
iface vmbr0 inet manual
    bridge-ports eno1
    bridge-stp off
    bridge-fd 0
    bridge-vlan-aware yes
    bridge-vids 10 30 40 50

# Management VLAN (Proxmox host)
auto vmbr0.10
iface vmbr0.10 inet static
    address 192.168.10.50/24
    gateway 192.168.10.1

# Storage bridge (dedicated USB NIC)
auto vmbr1
iface vmbr1 inet static
    address 192.168.20.50/24
    bridge-ports eth1
    bridge-stp off
    bridge-fd 0
    mtu 9000

# OPNsense VM WAN bridge (optional, for virtualized OPNsense)
auto vmbr2
iface vmbr2 inet manual
    bridge-ports none
    bridge-stp off
    bridge-fd 0
    comment "OPNsense WAN (connected to Deco/ONT)"
```

**VM Assignments:**
- **Services VMs:** vmbr0, VLAN tag 30
- **IoT/Test VMs:** vmbr0, VLAN tag 40
- **OPNsense LAN interface:** vmbr0, no VLAN tag (handles all VLANs)
- **Storage NFS mounts:** vmbr1 (no VLAN tag, dedicated network)

## Special Case: OPNsense as VM

### Network Interfaces for OPNsense VM
OPNsense needs two interfaces: WAN (Internet) and LAN (internal networks).

**Option 1: Bridged WAN (Simplest)**
```
WAN Interface (vtnet0): vmbr2 (bridge to physical, untagged)
  └─> Connects to Deco or ONT for Internet

LAN Interface (vtnet1): vmbr0 (VLAN-aware bridge)
  └─> Connects to all internal VLANs via VLAN tags
```

**Proxmox config:**
```
# vmbr2: WAN bridge (bridged to physical NIC, gets DHCP from ISP)
auto vmbr2
iface vmbr2 inet manual
    bridge-ports eno1
    bridge-stp off
    bridge-fd 0
```

**OPNsense VM config:**
- WAN interface: vmbr2 (gets DHCP from ISP, or PPPoE if needed)
- LAN interface: vmbr0 (VLAN-aware, handles all internal VLANs)

**Downside:** Proxmox host loses direct network access when OPNsense is off.

**Option 2: PCI Passthrough (Better but Complex)**
- Pass through physical NIC to OPNsense VM
- OPNsense has full control of hardware
- Requires IOMMU/VT-d enabled in BIOS
- Proxmox host needs second NIC (USB adapter) for management

**Option 3: OPNsense on Separate Hardware (Best)**
- Dedicated mini PC for OPNsense
- Proxmox remains independent
- No single point of failure
- More expensive (~$100-200 for hardware)

**Recommended:** Start with Option 1 (bridged), migrate to Option 3 if budget allows.

## Network Performance Optimization

### Enable VirtIO for VMs
- **VirtIO:** Paravirtualized network driver (best performance)
- **Intel E1000:** Emulated Intel NIC (slower, better compatibility)
- **Realtek:** Emulated Realtek (avoid)

**When creating VM:**
- Network Device → Model: VirtIO (paravirtualized)

**Performance gain:** 2-10x faster than emulated drivers

### Jumbo Frames (Storage VLAN)
Enable MTU 9000 on Storage VLAN for better throughput:

**Proxmox:**
```
auto vmbr1
iface vmbr1 inet static
    address 192.168.20.50/24
    bridge-ports eth1
    mtu 9000
```

**TrueNAS:**
- Network → Interfaces → Edit storage interface
- MTU: 9000

**VM (if accessing storage):**
```bash
# Inside VM
sudo ip link set ens18 mtu 9000
# Make permanent in network config
```

**Requirement:** All devices on Storage VLAN must support MTU 9000.

### Multiqueue VirtIO
For VMs with high network load:

**VM Config:**
```bash
# Edit VM config
nano /etc/pve/qemu-server/<VMID>.conf

# Add to network line:
net0: virtio=XX:XX:XX:XX:XX:XX,bridge=vmbr0,queues=4

# Restart VM
```

**Inside VM:**
```bash
# Check queues
ethtool -l ens18

# Should show 4 queues
```

**Performance gain:** Better CPU distribution for network I/O.

## Troubleshooting

### Can't Access Proxmox After Network Changes

**Prevention:**
- Always test changes with `ifreload -a` before rebooting
- Keep console access (monitor/keyboard or IPMI)
- Make changes during low-usage time

**Recovery:**
1. Connect monitor and keyboard to Dell 3080 Micro
2. Login as root
3. Edit `/etc/network/interfaces`
4. Fix configuration
5. Run `ifreload -a` or reboot

### VMs Can't Get Network
**Check:**
1. VM network device attached to correct bridge
2. Bridge is up: `ip link show vmbr0`
3. Physical NIC is up: `ip link show eno1`
4. Inside VM: `ip addr` shows interface
5. Firewall rules (if enabled on bridge)

### VLAN Traffic Not Working
**Check:**
1. Switch supports VLANs and is configured correctly
2. Switch port is trunk (tagged) mode
3. Correct VLAN tag set on VM network device
4. `bridge-vlan-aware yes` in Proxmox bridge config
5. VLAN ID in `bridge-vids` list

### Slow Network Performance
**Check:**
1. VM using VirtIO driver (not E1000)
2. Physical link speed: `ethtool eno1`
3. No errors: `ip -s link show eno1`
4. Switch not overloaded
5. MTU mismatch (should be 1500 unless jumbo frames)

### Can't Reach Gateway After VLAN Migration
**Check:**
1. Gateway IP correct for VLAN (e.g., 192.168.10.1 for VLAN 10)
2. OPNsense routing between VLANs
3. Firewall rules allow traffic
4. DNS set correctly (Pi-hole IP)

## Network Monitoring

### From Proxmox Host
```bash
# Show interfaces
ip addr

# Show bridge info
bridge link

# Show VLAN info (if VLAN-aware bridge)
bridge vlan

# Network statistics
ip -s link show vmbr0

# Test connectivity
ping 192.168.1.1  # Gateway
ping 8.8.8.8  # Internet
```

### From Proxmox Web UI
- Node → System → Network → View interface status
- Node → Monitor → Network graphs (bandwidth usage)

### Tools
- **iftop:** Real-time bandwidth monitoring
- **nethogs:** Per-process bandwidth usage
- **nload:** Simple bandwidth monitor

```bash
apt install iftop nethogs nload
iftop -i vmbr0
```

## Best Practices

1. **Use Static IPs for Infrastructure:**
   - TrueNAS, Proxmox, OPNsense should have static IPs
   - Makes management easier, more predictable

2. **Document Network Changes:**
   - Keep `/etc/network/interfaces` in Git
   - Comment changes with dates and reasons

3. **Test Before Committing:**
   - Use `ifreload -a` to test without rebooting
   - Keep console access available
   - Have rollback plan

4. **Separate Management and Storage:**
   - Use different VLANs (10 and 20)
   - Or separate physical NICs
   - Prevents storage traffic from affecting management

5. **Use VirtIO Drivers:**
   - Significantly better performance
   - Paravirtualized, less overhead

6. **Enable Firewall on Bridges (Optional):**
   - Adds extra layer of security
   - May affect performance slightly

7. **Monitor Network Usage:**
   - Watch for bottlenecks
   - Plan upgrades (10GbE) if needed

## Next Steps

1. Verify current Proxmox network configuration
2. Set static IP if not already configured
3. Test VM connectivity on vmbr0
4. Document current network setup in Git
5. Plan VLAN migration (Phase 8)
6. Research USB-to-Ethernet adapter for storage network

---

*Last Updated: 2025-01-26*