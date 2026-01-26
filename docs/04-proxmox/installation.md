# Proxmox VE Installation Guide

## Pre-Installation Planning

### Hardware Verification
Before installing Proxmox, verify your Dell OptiPlex 3080 Micro:
- [ ] CPU supports virtualization (VT-x/AMD-V)
- [ ] BIOS virtualization is enabled (VT-x, VT-d)
- [ ] RAM is properly detected (all 40GB showing)
- [ ] SSD is healthy and detected
- [ ] Network cable is connected

### BIOS Configuration
Access Dell BIOS (press F2 during boot):

**Required Settings:**
- **Virtualization Support:** Enabled
- **VT for Direct I/O:** Enabled (VT-d)
- **Boot Mode:** UEFI (recommended) or Legacy
- **Secure Boot:** Disabled (Proxmox doesn't support Secure Boot)

**Optional but Recommended:**
- **SATA Mode:** AHCI
- **Power Settings:** Disable sleep/hibernate (for 24/7 operation)
- **Boot Order:** USB first (for installation), then SSD

### Network Planning

**Phase 1 (Current Network):**
- Connect to existing network (192.168.1.0/24)
- Use DHCP initially, then set static IP
- Suggested static IP: 192.168.1.50 (or similar, avoid conflicts)
- Gateway: 192.168.1.1 (Deco router)
- DNS: 192.168.1.1 or 8.8.8.8

**Phase 2 (Future with OPNsense):**
- Management VLAN: 192.168.10.50
- Storage VLAN: 192.168.20.50

### Download Proxmox ISO

1. Visit: https://www.proxmox.com/en/downloads
2. Download latest Proxmox VE ISO installer
3. Verify checksum (optional but recommended)

**Current stable version:** Proxmox VE 8.x

## Creating Installation Media

### Using Rufus (Windows)
1. Download Rufus: https://rufus.ie/
2. Insert USB drive (8GB minimum, will be erased)
3. Configure Rufus:
   - **Device:** Your USB drive
   - **Boot selection:** Select Proxmox ISO
   - **Partition scheme:** GPT
   - **Target system:** UEFI (recommended)
   - **File system:** FAT32
4. Click "Start" and wait for completion

### Using Balena Etcher (Windows/Mac/Linux)
1. Download Etcher: https://www.balena.io/etcher/
2. Insert USB drive
3. Select Proxmox ISO
4. Select USB drive
5. Flash and verify

### Using dd (Linux)
```bash
# Find USB device
lsblk

# Write ISO to USB (replace sdX with your device)
sudo dd if=proxmox-ve_*.iso of=/dev/sdX bs=1M status=progress
sudo sync
```

## Installation Process

### Boot from USB
1. Insert USB drive into Dell 3080 Micro
2. Power on and press F12 for boot menu
3. Select USB drive from boot options
4. Proxmox installer will load

### Installation Steps

**1. Welcome Screen**
- Select "Install Proxmox VE (Graphical)"
- Press Enter

**2. EULA**
- Read End User License Agreement
- Click "I agree"

**3. Target Disk Selection**
- **Target Harddisk:** Select your 256GB SSD
- **Filesystem:** 
  - Recommended: `ext4` (simple, reliable)
  - Advanced: `zfs` (if you want snapshots, but overkill for 256GB)
  - Choose: `ext4`
- **hdsize:** Leave default (uses entire disk)
- **swapsize:** Default (based on RAM, ~8GB)
- **maxroot:** Default (rest for data)
- **minfree:** Default (16GB reserved)

**Option Details:**
```
Disk Layout (ext4):
├── /dev/sda1 - 1GB   - EFI System Partition
├── /dev/sda2 - 8GB   - Swap
├── /dev/sda3 - ~220GB - Proxmox root (/) and data
└── (16GB reserved as buffer)
```

**4. Location and Time Zone**
- **Country:** United States
- **Time zone:** America/Chicago (Keller, Texas)
- **Keyboard Layout:** U.S. English

**5. Administration Password and Email**
- **Password:** Choose strong password (save in password manager)
- **Confirm Password:** Re-enter
- **Email:** Your email address (for system alerts)

**Important:** This creates the `root` user for Proxmox web interface and SSH.

**6. Network Configuration**
- **Management Interface:** (Should auto-detect single NIC)
- **Hostname (FQDN):** `proxmox.homelab.local` or `pve.homelab.local`
- **IP Address (CIDR):** `192.168.1.50/24` (or choose available IP)
- **Gateway:** `192.168.1.1`
- **DNS Server:** `192.168.1.1` (or `8.8.8.8`)

**Network Notes:**
- Use static IP to avoid management interface changing
- FQDN should be resolvable (add to Deco DNS or hosts file)
- Can change these later if needed

**7. Summary**
- Review all settings
- Click "Install" when ready
- Installation takes 5-10 minutes

**8. Reboot**
- Remove USB drive when prompted
- System will reboot into Proxmox VE

## Post-Installation Setup

### First Login (Web Interface)

1. **Access Web UI:**
   - URL: `https://192.168.1.50:8006`
   - Browser will show security warning (self-signed cert - normal)
   - Click "Advanced" → "Proceed" or "Accept Risk"

2. **Login Credentials:**
   - **Username:** `root`
   - **Password:** What you set during installation
   - **Realm:** `Linux PAM standard authentication`

3. **First Login:**
   - You'll see a subscription notice (ignore for homelab - click OK)
   - Proxmox dashboard will load

### Initial Configuration Tasks

#### 1. Update System
```bash
# SSH into Proxmox
ssh root@192.168.1.50

# Update package lists
apt update

# Upgrade all packages
apt dist-upgrade -y

# Reboot if kernel was updated
reboot
```

#### 2. Remove Enterprise Repository (No Subscription)
Proxmox defaults to enterprise repos which require a subscription. Switch to no-subscription repos:

```bash
# Disable enterprise repo
mv /etc/apt/sources.list.d/pve-enterprise.list /etc/apt/sources.list.d/pve-enterprise.list.bak

# Add no-subscription repo
echo "deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription" > /etc/apt/sources.list.d/pve-no-subscription.list

# Update again
apt update
```

#### 3. Disable Subscription Nag (Optional)
```bash
# Backup original file
cp /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js.bak

# Edit file to remove nag
sed -i.bak "s/data.status !== 'Active'/false/g" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js

# Restart web service
systemctl restart pveproxy
```

Refresh browser - subscription nag should be gone.

#### 4. Configure Firewall (Optional but Recommended)
```bash
# Enable Proxmox firewall
pvesh set /cluster/firewall/options --enable 1

# Allow SSH, web interface, and ICMP by default
# Configure via web UI: Datacenter → Firewall → Add rules
```

**Recommended firewall rules:**
- **SSH (22):** Allow from your workstation IP
- **Web Interface (8006):** Allow from your subnet
- **ICMP:** Allow (for ping)
- **Default:** Drop

#### 5. Set up NTP (Time Synchronization)
```bash
# Verify NTP is working
timedatectl status

# If needed, configure NTP
nano /etc/systemd/timesyncd.conf
# Add: NTP=time.google.com

# Restart service
systemctl restart systemd-timesyncd
```

#### 6. Create Backup Directory Structure
```bash
# Create local dirs for organization
mkdir -p /var/lib/vz/template/iso
mkdir -p /var/lib/vz/template/cache
mkdir -p /root/scripts
```

### Configure Storage

#### Local Storage (Already Configured)
Proxmox auto-creates:
- **local:** For ISOs, backups, container templates
- **local-lvm:** For VM disks

Verify in Web UI: Datacenter → Storage

#### Add TrueNAS NFS Storage

**On TrueNAS (via web UI):**
1. Create dataset: `/tank/proxmox` with subdirectories:
   - `/tank/proxmox/backups`
   - `/tank/proxmox/isos`
   - `/tank/proxmox/templates`

2. Share `/tank/proxmox` via NFS:
   - Path: `/mnt/tank/proxmox`
   - Network: `192.168.1.0/24`
   - Permissions: `root` access (maproot=root)

**On Proxmox (via web UI):**
1. Datacenter → Storage → Add → NFS
2. Configure:
   - **ID:** `truenas-backups`
   - **Server:** `192.168.1.X` (TrueNAS IP)
   - **Export:** `/mnt/tank/proxmox`
   - **Content:** Select all appropriate types
3. Click "Add"

**Test mount:**
```bash
# Should show TrueNAS storage
pvesm status

# Test write
touch /mnt/pve/truenas-backups/test.txt
```

### Upload ISOs

Download and upload common ISOs:

**Linux:**
- Ubuntu Server 24.04 LTS
- Rocky Linux 9
- Debian 12

**Other:**
- Windows 10/11 (if licensed)

**Upload via Web UI:**
1. Select `truenas-backups` storage
2. Click "ISO Images" → "Upload"
3. Select ISO file from your computer

**Or via CLI:**
```bash
# Download directly to Proxmox
cd /var/lib/vz/template/iso
wget https://releases.ubuntu.com/24.04/ubuntu-24.04-live-server-amd64.iso
```

### Enable IOMMU (for GPU Passthrough - Optional)

If you plan to pass through iGPU to VMs:

```bash
# Edit GRUB config
nano /etc/default/grub

# Add to GRUB_CMDLINE_LINUX_DEFAULT:
# For Intel:
intel_iommu=on iommu=pt

# Example line:
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt"

# Update GRUB
update-grub

# Reboot
reboot
```

Verify after reboot:
```bash
dmesg | grep -e DMAR -e IOMMU
# Should show IOMMU enabled
```

## Verification Checklist

After installation and setup:
- [ ] Web interface accessible at https://192.168.1.50:8006
- [ ] Can SSH to root@192.168.1.50
- [ ] System is updated (apt update && apt dist-upgrade)
- [ ] No-subscription repo configured
- [ ] TrueNAS NFS storage mounted
- [ ] At least one ISO uploaded
- [ ] Firewall rules configured
- [ ] Time synchronization working
- [ ] System stable and no errors in dashboard

## Next Steps

1. Create first VM (see [first-vms.md](first-vms.md))
2. Set up VM templates for quick cloning
3. Configure automated backups to TrueNAS
4. Explore Proxmox web interface features

## Troubleshooting

### Can't Access Web Interface
- Verify IP address: `ip addr show`
- Check firewall: `iptables -L`
- Verify service: `systemctl status pveproxy`

### NFS Mount Fails
- Check TrueNAS NFS service is running
- Verify network connectivity: `ping 192.168.1.X`
- Check mount manually: `mount -t nfs 192.168.1.X:/mnt/tank/proxmox /mnt/test`

### Subscription Nag Returns
- Happens after Proxmox updates
- Re-run the sed command from step 3

---

*Last Updated: 2025-01-26*