# Post-Installation Boot Fix

## Problem: `/boot/vmlinuz not found` After Installation

If you see this error after installing NubiferOS using Calamares, it means the kernel wasn't properly installed on your system.

## Symptoms

- GRUB menu appears
- After selecting boot option, error: `/boot/vmlinuz not found`
- System won't boot into installed OS

## Root Cause

The Calamares installer configuration was missing explicit kernel package installation. While Calamares typically handles this automatically, some configurations require explicit package specification.

## Fix (From Live ISO)

### Step 1: Boot from Live ISO

Boot your system using the NubiferOS installation ISO.

### Step 2: Identify Your Installation Partition

```bash
# List all partitions
lsblk

# Look for your root partition (usually the largest ext4 partition)
# Example: /dev/sda2 or /dev/nvme0n1p2
```

### Step 3: Mount and Chroot

Replace `/dev/sdaX` with your actual root partition:

```bash
# Mount the installed system
sudo mount /dev/sdaX /mnt

# If you have a separate /boot partition, mount it too:
# sudo mount /dev/sdaY /mnt/boot

# Mount system directories
sudo mount --bind /dev /mnt/dev
sudo mount --bind /proc /mnt/proc
sudo mount --bind /sys /mnt/sys
sudo mount --bind /run /mnt/run

# If using EFI, mount the EFI partition:
# sudo mount /dev/sdaZ /mnt/boot/efi

# Chroot into the installed system
sudo chroot /mnt
```

### Step 4: Install Kernel and Fix GRUB

```bash
# Update package lists
apt-get update

# Install kernel
apt-get install -y linux-image-amd64 linux-headers-amd64

# Verify kernel is installed
ls -la /boot/vmlinuz*

# Recreate initramfs
update-initramfs -u -k all

# Verify initramfs is created
ls -la /boot/initrd.img*

# Reinstall GRUB
# For BIOS systems:
grub-install /dev/sda

# For UEFI systems:
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=nubiferos

# Update GRUB configuration
update-grub

# Verify GRUB config references correct kernel
grep vmlinuz /boot/grub/grub.cfg
```

### Step 5: Exit and Reboot

```bash
# Exit chroot
exit

# Unmount everything
sudo umount /mnt/run
sudo umount /mnt/sys
sudo umount /mnt/proc
sudo umount /mnt/dev
# If you mounted /boot/efi:
# sudo umount /mnt/boot/efi
# If you mounted /boot separately:
# sudo umount /mnt/boot
sudo umount /mnt

# Reboot
sudo reboot
```

Remove the installation ISO and boot from your hard drive.

## Prevention

This issue has been fixed in the Calamares configuration. Future installations will automatically include:

- `linux-image-amd64` - The kernel
- `linux-headers-amd64` - Kernel headers for module compilation
- `grub-pc` or `grub-efi-amd64` - GRUB bootloader

## Verification After Fix

After rebooting, verify your system:

```bash
# Check kernel version
uname -r

# Check installed kernels
dpkg -l | grep linux-image

# Check GRUB installation
grub-install --version
```

## Alternative: Reinstall

If the above fix doesn't work or seems too complex, you can:

1. Rebuild the ISO with the fixed configuration
2. Reinstall NubiferOS from scratch

The new ISO will have the kernel properly installed during Calamares installation.

## Technical Details

### Why This Happened

Calamares has two ways to ensure kernel installation:

1. **Implicit**: Calamares automatically installs a kernel if none is present
2. **Explicit**: The `packages.conf` lists kernel packages

The original configuration relied on implicit installation, which can fail in certain scenarios. The fix adds explicit kernel package installation to `installer/calamares/modules/packages.conf`.

### Files Modified

- `installer/calamares/modules/packages.conf` - Added kernel packages to install list

### Related Issues

- GRUB installed but no kernel to boot
- Missing `/boot/vmlinuz` and `/boot/initrd.img` symlinks
- Empty `/boot` directory after installation

## Getting Help

If this fix doesn't resolve your issue:

1. Check that your disk has enough space (at least 20GB free)
2. Verify your partition table is correct (`sudo fdisk -l`)
3. Check for disk errors (`sudo fsck /dev/sdaX`)
4. Review Calamares installation logs in `/var/log/calamares/`

## See Also

- [Boot Troubleshooting Guide](BOOT_TROUBLESHOOTING.md)
- [GRUB Bootloader Fix](GRUB_BOOTLOADER_FIX.md)
- [Post-Installation Testing](POST_INSTALL_TESTING.md)
