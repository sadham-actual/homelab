# Proxmox Upgrades and Kernel Pinning

How package upgrades are applied across the cluster, and how the boot kernel is controlled. Written after upgrading all three nodes from PVE 9.1.x to 9.2.11 and converging them on a single kernel.

## Package upgrades

### Use `dist-upgrade`, not `upgrade`

Plain `apt upgrade` holds back Proxmox packages whose dependencies changed — 11 to 18 per node in practice, including `pve-manager`, `pve-container`, `qemu-server`, `libpve-*` and the kernel metapackages. That leaves the node half-upgraded, with the web UI on one version and libraries on another.

```bash
apt-get update
apt-get -s dist-upgrade          # ALWAYS simulate first
```

Read the simulation before running it for real. The lines that matter:

| Line | Meaning |
|------|---------|
| `Remv` | something is being **removed** — read every one of these |
| `Inst proxmox-kernel-*` | a new kernel is being installed (does not remove old ones) |
| `N upgraded, N newly installed, N to remove` | the headline |

### Running the upgrade

```bash
DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y \
  -o Dpkg::Options::="--force-confold" \
  -o Dpkg::Options::="--force-confdef"
```

`--force-confold` keeps existing config files when a package ships a new version. On a cluster this is the safe default — an overwritten `corosync.conf` or network config is far worse than a slightly stale one. Review `.dpkg-dist` leftovers afterwards if you care.

### Order matters

**One node at a time, idle nodes first.** The upgrade restarts `corosync`, which briefly drops that node from the ring. With three nodes, one dropping keeps quorum at 2; two dropping does not.

1. Idle node → verify → next
2. Idle node → verify → next
3. Node hosting guests **last**

Running guests are **not** interrupted by the upgrade. A VM keeps its existing QEMU process (and therefore the old QEMU binary) until it is stopped and started — a guest reboot is not enough. Verify with the PID:

```bash
qm list      # PID should be unchanged after the upgrade
```

### Verify after each node

```bash
systemctl list-units --state=failed --no-legend | wc -l    # expect 0
pvecm status | grep -E "Quorate|Total votes"               # expect Yes / 3
for s in pve-cluster corosync pvedaemon pveproxy pvestatd \
         pve-firewall pve-ha-lrm pve-ha-crm; do
  printf "%-14s %s\n" "$s" "$(systemctl is-active $s)"
done
```

One peer-loss event per node in the corosync log is expected — that is corosync restarting during its own upgrade.

## Kernel pinning

These nodes boot via **GRUB**, not `proxmox-boot-tool` ESP sync. `proxmox-boot-tool kernel pin` writes `/etc/kernel/proxmox-boot-pin`, but **nothing reads it here** — it has no effect.

### The trap: where the pin actually lives

`GRUB_DEFAULT` can be set in two places, and they are not equal:

| Location | Precedence |
|---|---|
| `/etc/default/grub` | base |
| `/etc/default/grub.d/*.cfg` | **sourced afterwards — overrides the above** |

If a drop-in exists, editing `/etc/default/grub` does nothing. It will *look* like it worked: the file shows your change and `update-grub` reports `done`, but the generated config keeps the old value.

**Never trust the source file.** Always confirm the generated result:

```bash
grep -oE 'set default="gnulinux-advanced[^"]*' /boot/grub/grub.cfg
```

### Setting a pin

The value is `<submenu-id>><entry-id>`, both containing the root filesystem UUID. Get them from the generated config:

```bash
grep -oE "gnulinux-advanced-[a-f0-9-]+" /boot/grub/grub.cfg | head -1   # submenu id
grep -oE "gnulinux-[0-9][^\"']*-advanced-[a-f0-9-]+" /boot/grub/grub.cfg  # entry ids
```

Then write it to whichever location that node uses, run `update-grub`, and verify as above.

### Why pin at all

`GRUB_DEFAULT=0` means "first menu entry", which is the **newest installed kernel**. That is fine until an upgrade installs a kernel you have never booted — then the next reboot, quite possibly an unattended one after a power cut, silently becomes that kernel's first boot on that hardware.

A pin makes the boot kernel an explicit decision. Two ways to use it:

- **Pin to the running, proven kernel** while a new one is untested. An unattended reboot lands somewhere known-good.
- **Pin to a new kernel** once it is proven, to converge the fleet.

Move the pin *after* validating, not before, unless you accept that the next boot is the test.

### Testing a new kernel safely

Pick it from the GRUB menu at the console rather than pinning it first. If it fails, power-cycle and the pin brings back the known-good kernel automatically.

Do **not** use `grub-reboot` one-shots on these nodes — `grubenv` sits on LVM, so the one-shot is sticky rather than self-clearing.

### Menu timeout: fast normally, generous on failure

A 5-second menu is regularly missed, because a monitor often has not finished syncing before it elapses. But a 30-second menu on every boot is tedious.

GRUB distinguishes the two cases via its `recordfail` flag:

```bash
GRUB_TIMEOUT=5                # normal boot — quick
GRUB_RECORDFAIL_TIMEOUT=30    # after a FAILED boot — time to pick a fallback
```

That gives a long menu exactly when a fallback kernel is needed, and a short one the rest of the time.

Confirm both landed:

```bash
sed -n '86p;90p' /boot/grub/grub.cfg    # recordfail path / normal path
```

### Keep fallback kernels installed

Proxmox kernel metapackage upgrades install alongside, they do not remove. That accumulation is a feature — every previously-working kernel stays selectable from the menu. Check `/boot` space occasionally rather than pruning reflexively; these nodes have tens of GB free.

## Result of the 2026-09-04 upgrade

All three nodes went from PVE 9.1.x to **9.2.11 / proxmox-ve 9.2.0** and converged on kernel **7.0.14-15-pve**:

| Step | Outcome |
|---|---|
| Packages | 180–215 per node, 0 removed (except one ZFS library transition) |
| Failed units afterwards | 0 on all three |
| Guests | never restarted — same PID throughout |
| Quorum | 3/3 maintained, one expected corosync blip per node |
| Reboots | 3, **zero unsafe shutdowns** |

`proxmox-default-kernel` moving to 2.1.0 is what switched the default series to 7.0 and pulled 7.0.14-15 onto every node.

The kernel was validated on one idle node first (selected from the console menu), then rolled to the rest by moving their pins.

---

*Last Updated: 2026-09-04*
