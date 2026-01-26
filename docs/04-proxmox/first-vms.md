# Creating Your First VMs in Proxmox

## Prerequisites

Before creating VMs, ensure:
- [ ] Proxmox installed and accessible via web UI
- [ ] TrueNAS NFS storage mounted (for ISOs and backups)
- [ ] At least one ISO uploaded (Ubuntu Server 24.04 LTS recommended)
- [ ] Network configured (vmbr0 working)

## Understanding VM IDs

Proxmox assigns each VM a unique ID number:
- **100-199:** Reserved for templates
- **200-299:** Infrastructure VMs (monitoring, automation)
- **300-399:** Application VMs (services, *arr stack)
- **400-499:** Test/experimental VMs
- **500-599:** Kubernetes cluster VMs

**Best Practice:** Plan your numbering scheme and document it.

## VM 1: Ubuntu Server 24.04 LTS (Test VM)

### Purpose
First VM for learning Proxmox basics and testing configuration.

### Specifications
- **VM ID:** 400 (test VM)
- **Name:** ubuntu-test-01
- **OS:** Ubuntu Server 24.04 LTS
- **CPUs:** 2 cores
- **RAM:** 2048 MB (2GB)
- **Disk:** 20 GB
- **Network:** vmbr0

### Step-by-Step Creation

#### 1. Download Ubuntu ISO

**Option A: Download to TrueNAS, then access via NFS**
```bash
# On TrueNAS (via SSH or web shell)
cd /mnt/tank/proxmox/isos
wget https://releases.ubuntu.com/24.04/ubuntu-24.04-live-server-amd64.iso
```

**Option B: Upload via Proxmox Web UI**
1. Select `truenas-backups` storage
2. Click "ISO Images" → "Upload"
3. Select downloaded ISO from your computer

**Option C: Download directly to Proxmox**
```bash
# SSH to Proxmox
cd /var/lib/vz/template/iso
wget https://releases.ubuntu.com/24.04/ubuntu-24.04-live-server-amd64.iso
```

#### 2. Create VM (Web UI)

**General Tab:**
1. Click "Create VM" (top-right)
2. **Node:** pve (your Proxmox node)
3. **VM ID:** 400
4. **Name:** ubuntu-test-01
5. **Resource Pool:** (leave blank for now)
6. Click "Next"

**OS Tab:**
1. **ISO Image:** Select ubuntu-24.04-live-server-amd64.iso
2. **Type:** Linux
3. **Version:** 6.x - 2.6 Kernel
4. Click "Next"

**System Tab:**
1. **Graphic card:** Default
2. **Machine:** Default (i440fx)
3. **BIOS:** Default (SeaBIOS)
4. **SCSI Controller:** VirtIO SCSI single
5. **Qemu Agent:** Check "enabled" (install agent later)
6. Click "Next"

**Disks Tab:**
1. **Bus/Device:** SCSI 0
2. **Storage:** local-lvm (or truenas-backups if using NFS)
3. **Disk size:** 20 GB
4. **Cache:** Default (No cache)
5. **Discard:** Check (enables TRIM for SSDs)
6. **SSD emulation:** Check if using SSD storage
7. Click "Next"

**CPU Tab:**
1. **Sockets:** 1
2. **Cores:** 2
3. **Type:** x86-64-v2-AES (or host if you want)
4. Click "Next"

**Memory Tab:**
1. **Memory:** 2048 MB
2. **Minimum memory:** 1024 MB (ballooning)
3. **Ballooning Device:** Enabled
4. Click "Next"

**Network Tab:**
1. **Bridge:** vmbr0
2. **VLAN Tag:** (leave blank)
3. **Model:** VirtIO (paravirtualized)
4. **MAC address:** Auto-generate
5. **Firewall:** Unchecked (for now)
6. Click "Next"

**Confirm:**
1. Review settings
2. **Start after created:** Check this
3. Click "Finish"

#### 3. Install Ubuntu

VM will auto-start and boot from ISO.

**Access Console:**
1. Select VM (400) in left sidebar
2. Click "Console" (or click ">_ Console" button)
3. You'll see Ubuntu installer

**Installation Steps:**
1. **Language:** English
2. **Keyboard:** English (US)
3. **Type of install:** Ubuntu Server (not minimized)
4. **Network:** Should auto-detect via DHCP
5. **Proxy:** Leave blank
6. **Mirror:** Default (archive.ubuntu.com)
7. **Storage:**
   - Use entire disk
   - Set up this disk as an LVM group
   - Confirm disk layout
8. **Profile:**
   - Your name: Your Name
   - Server name: ubuntu-test-01
   - Username: youruser
   - Password: [choose strong password]
9. **SSH:** Enable OpenSSH server (important!)
10. **Import SSH identity:** No (unless you have one)
11. **Featured snaps:** None (skip)
12. Wait for installation (5-10 minutes)
13. **Reboot:** When prompted, press Enter

**After Reboot:**
1. Console will show login prompt
2. Login with username/password you created
3. Update system:
```bash
sudo apt update
sudo apt upgrade -y
```

#### 4. Install QEMU Guest Agent

**Why:** Allows Proxmox to communicate with VM (shutdown, IP detection, etc.)

```bash
sudo apt install qemu-guest-agent
sudo systemctl enable qemu-guest-agent
sudo systemctl start qemu-guest-agent
```

**In Proxmox Web UI:**
1. Shutdown VM (from console: `sudo shutdown now`)
2. Select VM → Options → QEMU Guest Agent
3. Edit → Enable
4. Start VM

**Verify:** VM summary now shows IP address and more details.

#### 5. Configure Static IP (Optional but Recommended)

**Find current IP:**
```bash
ip addr show
# Note the IP, e.g., 192.168.1.150
```

**Edit Netplan config:**
```bash
sudo nano /etc/netplan/00-installer-config.yaml
```

**Change from DHCP to static:**
```yaml
network:
  version: 2
  ethernets:
    ens18:
      addresses:
        - 192.168.1.150/24
      routes:
        - to: default
          via: 192.168.1.1
      nameservers:
        addresses: [192.168.1.1, 8.8.8.8]
```

**Apply:**
```bash
sudo netplan apply
```

**Test:**
```bash
ping 192.168.1.1
ping google.com
```

#### 6. SSH Access

From your workstation:
```bash
ssh youruser@192.168.1.150
```

Should connect without using Proxmox console.

**Optional: Copy SSH key for passwordless login:**
```bash
# From your workstation
ssh-copy-id youruser@192.168.1.150
```

### Testing Your First VM

**Basic checks:**
```bash
# Check CPU
lscpu

# Check memory
free -h

# Check disk
df -h

# Check network
ip addr
ip route

# Install htop for monitoring
sudo apt install htop
htop
```

**Install Docker (for future services):**
```bash
# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER

# Logout and login again
exit
ssh youruser@192.168.1.150

# Test Docker
docker run hello-world
```

## VM 2: Rocky Linux 9 (RHEL-based Learning)

### Purpose
Learn Red Hat-based Linux (good for certifications and enterprise environments).

### Specifications
- **VM ID:** 401
- **Name:** rocky-test-01
- **OS:** Rocky Linux 9
- **CPUs:** 2 cores
- **RAM:** 2048 MB
- **Disk:** 20 GB
- **Network:** vmbr0

### Download ISO
```bash
# On Proxmox
cd /var/lib/vz/template/iso
wget https://download.rockylinux.org/pub/rocky/9/isos/x86_64/Rocky-9-latest-x86_64-minimal.iso
```

### Create VM (Similar to Ubuntu)
Follow same steps as Ubuntu, but select Rocky Linux ISO.

### Installation Differences
1. **Installation Summary:** Graphical installer (not text-based)
2. **Software Selection:** Minimal Install
3. **Network:** Enable and set hostname
4. **Root Password:** Set strong password
5. **User Creation:** Create user account
6. **Reboot after installation**

### Post-Install Configuration

**Update system:**
```bash
sudo dnf update -y
```

**Install QEMU Guest Agent:**
```bash
sudo dnf install qemu-guest-agent -y
sudo systemctl enable --now qemu-guest-agent
```

**Install useful tools:**
```bash
sudo dnf install vim wget curl htop -y
```

**Configure firewall (firewalld):**
```bash
# Check status
sudo systemctl status firewalld

# Allow SSH
sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --reload
```

**SELinux (Security-Enhanced Linux):**
```bash
# Check status
sestatus

# Should be Enforcing (good for security learning)
```

### Key Differences from Ubuntu
- Package manager: `dnf` instead of `apt`
- Firewall: `firewalld` instead of `ufw`
- SELinux enabled by default (Ubuntu uses AppArmor)
- Network config: `/etc/sysconfig/network-scripts/` or NetworkManager

## Creating a VM Template

### Why Templates?
- Quickly clone VMs without reinstalling
- Pre-configured with common software
- Consistent baseline for all VMs

### Steps to Create Template

#### 1. Create and Configure Base VM
- Create VM (ID 100, name: ubuntu-template)
- Install Ubuntu Server
- Update system: `sudo apt update && sudo apt upgrade -y`
- Install common tools:
```bash
sudo apt install -y \
  vim curl wget git htop \
  qemu-guest-agent \
  cloud-init
```

#### 2. Configure Cloud-Init
Cloud-init allows automatic configuration on first boot (IP, hostname, SSH keys).

```bash
# Cloud-init should be installed
sudo apt install cloud-init

# Clean cloud-init state
sudo cloud-init clean
```

**Enable cloud-init in Proxmox:**
1. Select VM 100
2. Hardware → Add → CloudInit Drive
3. Storage: local-lvm
4. CloudInit tab will appear

**Configure defaults:**
1. CloudInit tab
2. Set default user, password, SSH keys
3. DNS: 192.168.1.1
4. IP Config: DHCP (will be set per clone)

#### 3. Clean and Prepare for Template
```bash
# Remove machine-specific IDs
sudo rm -f /etc/machine-id
sudo rm -f /var/lib/dbus/machine-id

# Clear logs
sudo truncate -s 0 /var/log/*.log

# Clear bash history
history -c
cat /dev/null > ~/.bash_history

# Shutdown
sudo shutdown now
```

#### 4. Convert to Template
1. Right-click VM 100
2. Select "Convert to template"
3. Confirm

**VM 100 is now a template** (cannot be started directly).

### Cloning from Template

**Full Clone (Recommended):**
1. Right-click template (100)
2. Clone
3. **VM ID:** 402
4. **Name:** ubuntu-web-01
5. **Mode:** Full Clone
6. **Target Storage:** local-lvm
7. Click "Clone"

**Linked Clone (Faster but dependent on template):**
- Same steps but select "Linked Clone"
- Uses less storage but can't delete template

**Configure Cloned VM:**
1. Select cloned VM (402)
2. CloudInit tab → Set hostname, IP, SSH keys
3. Regenerate VM ID (if needed)
4. Start VM

**Benefit:** VM boots fully configured, no manual setup needed.

## VM Management Basics

### Starting/Stopping VMs

**Web UI:**
- Select VM → Start / Shutdown / Stop / Reset
- **Shutdown:** Graceful (requires QEMU agent)
- **Stop:** Force power off (like pulling plug)

**CLI:**
```bash
# List VMs
qm list

# Start VM
qm start 400

# Shutdown (graceful)
qm shutdown 400

# Stop (force)
qm stop 400

# Reboot
qm reboot 400

# Check status
qm status 400
```

### Snapshots

**Why:** Save VM state before making changes, easy rollback.

**Create Snapshot:**
1. Select VM → Snapshots
2. Take Snapshot
3. Name: "before-update" or similar
4. Description: Optional
5. Include RAM: No (for offline snapshot)
6. Click "Take Snapshot"

**Rollback:**
1. Snapshots tab
2. Select snapshot
3. Rollback
4. Confirm

**Delete Snapshot:**
- Select snapshot → Delete

**CLI:**
```bash
# Create snapshot
qm snapshot 400 before-update

# List snapshots
qm listsnapshot 400

# Rollback
qm rollback 400 before-update

# Delete snapshot
qm delsnapshot 400 before-update
```

### Backups

**Manual Backup:**
1. Select VM → Backup
2. Backup now
3. Storage: truenas-backups
4. Mode: Snapshot (fastest) or Stop (safest)
5. Compression: ZSTD (good balance)
6. Click "Backup"

**Scheduled Backups:**
1. Datacenter → Backup
2. Add
3. Schedule: Daily at 2 AM (or preferred time)
4. Selection Mode: All or specific VMs
5. Storage: truenas-backups
6. Retention: Keep last 7 (adjust as needed)
7. Click "Create"

**Restore from Backup:**
1. Storage → truenas-backups → Backups
2. Select backup file
3. Restore
4. VM ID: New or overwrite existing
5. Start after restore: Optional

### Resizing VM Resources

**Add More RAM:**
1. Shutdown VM
2. Hardware → Memory → Edit
3. Increase value
4. Start VM

**Add More CPU:**
1. Shutdown VM
2. Hardware → Processors → Edit
3. Increase cores
4. Start VM

**Resize Disk:**
1. VM can be running
2. Hardware → Hard Disk → Resize
3. Add amount (e.g., +10 GB)
4. Inside VM, resize partition:
```bash
# Ubuntu/Debian
sudo lvextend -l +100%FREE /dev/ubuntu-vg/ubuntu-lv
sudo resize2fs /dev/ubuntu-vg/ubuntu-lv

# Verify
df -h
```

## Common VM Configurations

### Web Server VM

**Specs:**
- 2 CPU, 2GB RAM, 20GB disk
- Install Apache/Nginx
- Open port 80/443

**Quick setup:**
```bash
# Install Nginx
sudo apt install nginx -y

# Start and enable
sudo systemctl enable --now nginx

# Test
curl http://localhost
```

### Database VM

**Specs:**
- 2 CPU, 4GB RAM, 50GB disk
- Install PostgreSQL or MySQL
- Mount TrueNAS NFS for data

**Quick setup:**
```bash
# Install PostgreSQL
sudo apt install postgresql postgresql-contrib -y

# Check status
sudo systemctl status postgresql
```

### Docker Host VM

**Specs:**
- 4 CPU, 8GB RAM, 50GB disk
- Install Docker and Docker Compose
- Run multiple containers

**Setup in previous Ubuntu test VM example**

## Monitoring VM Performance

### Web UI Metrics
1. Select VM → Summary
2. See CPU, RAM, network, disk usage graphs
3. Real-time and historical data

### Inside VM
```bash
# CPU and memory
htop

# Disk I/O
iostat -x 2

# Network
iftop -i ens18

# Overall stats
vmstat 2
```

### From Proxmox Host
```bash
# Show all VMs resource usage
qm list

# Detailed info for specific VM
qm config 400
qm status 400 -verbose
```

## Troubleshooting

### VM Won't Start
**Check:**
1. Error message in task log (Proxmox UI)
2. Storage available (disk full?)
3. RAM available on host
4. VM config file: `/etc/pve/qemu-server/<VMID>.conf`

### VM Has No Network
**Check:**
1. Network device attached (Hardware tab)
2. Correct bridge (vmbr0)
3. Inside VM: `ip addr` shows interface
4. Inside VM: `ip route` shows gateway
5. Firewall rules (if enabled)

### QEMU Agent Not Working
**Check:**
1. Agent installed in VM: `systemctl status qemu-guest-agent`
2. Agent enabled in VM Options
3. VM rebooted after enabling

### Slow Performance
**Check:**
1. Using VirtIO drivers (not IDE/E1000)
2. Ballooning not over-allocating RAM
3. Host has resources available
4. Storage not overloaded (check IOPS)

### Can't SSH to VM
**Check:**
1. SSH service running: `sudo systemctl status ssh`
2. Firewall allows SSH: `sudo ufw status` or `sudo firewall-cmd --list-all`
3. Correct IP address
4. Network connectivity: `ping 192.168.1.1` from VM

## Best Practices

1. **Always Install QEMU Guest Agent**
   - Enables better VM management
   - Shows IP address in Proxmox UI
   - Allows graceful shutdown

2. **Use VirtIO Drivers**
   - Network: VirtIO
   - Disk: VirtIO SCSI
   - Much better performance than emulated hardware

3. **Create Templates**
   - Don't reinstall OS repeatedly
   - Templates ensure consistency
   - Use cloud-init for per-VM customization

4. **Take Snapshots Before Changes**
   - Before major updates
   - Before installing new software
   - Easy rollback if something breaks

5. **Set Up Automated Backups**
   - Daily backups to TrueNAS
   - Keep at least 7 days of history
   - Test restore procedure

6. **Use Static IPs for Servers**
   - Services should have predictable IPs
   - Makes firewall rules easier
   - Better for documentation

7. **Document Your VMs**
   - Keep list of VM IDs, names, purposes
   - Note any special configuration
   - Track IP addresses

8. **Don't Over-Allocate Resources**
   - Start small (2 CPU, 2GB RAM)
   - Increase if needed
   - Monitor actual usage

9. **Use Meaningful Names**
   - `ubuntu-web-01` instead of `vm1`
   - Include purpose in name
   - Easier to manage at scale

10. **Test in Non-Production First**
    - Use test VMs (ID 400-499) for experimenting
    - Once stable, migrate to production (ID 300-399)
    - Keep production VMs clean and documented

## Next Steps

1. Create Ubuntu test VM (ID 400)
2. Install Docker on test VM
3. Deploy first container (hello-world)
4. Create Rocky Linux test VM (ID 401)
5. Create Ubuntu template (ID 100)
6. Clone template to create first service VM
7. Begin service migration (Uptime Kuma as first target)

---

*Last Updated: 2025-01-26*