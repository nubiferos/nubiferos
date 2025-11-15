# GRUB Bootloader Fix

## Problem Summary

The ISO build was failing to create a properly bootable image due to incorrect GRUB configuration. The issues were:

1. **Incorrect xorriso parameters**: Using `-eltorito-boot boot/grub/grub.cfg` which pointed to a config file instead of a boot image
2. **Missing UEFI support**: No EFI boot image was being created
3. **Wrong boot files**: Referenced `/usr/lib/ISOLINUX/isohdpfx.bin` which may not exist
4. **No hybrid boot**: ISO wasn't configured for both BIOS and UEFI boot modes
5. **Missing live-boot**: The `live-boot` package wasn't installed, causing boot failures
6. **GRUB crash on boot**: Exception 14 errors due to missing modules and incorrect configuration

## Solution Implemented

### 1. Proper GRUB Installation (install-desktop.sh)

Already correctly using `-bin` packages to avoid conflicts:
```bash
grub-pc-bin          # BIOS boot files only
grub-efi-amd64-bin   # UEFI boot files only
grub-common          # Common utilities
grub2-common         # Common files
```

This avoids the conflict between `grub-pc` and `grub-efi-amd64` full packages which both try to install to the same system.

### 1.1. Live Boot Support

Added essential live-boot packages:
```bash
live-boot                    # Live system boot scripts
live-boot-initramfs-tools    # Initramfs integration
```

These packages enable the system to boot from the ISO as a live environment, detecting and mounting the squashfs filesystem.

### 2. Hybrid BIOS/UEFI Boot Image Creation (build-iso.sh)

The `create_bootable_iso()` function now:

#### Creates proper directory structure:
- `/boot/grub/` - BIOS boot files
- `/EFI/boot/` - UEFI boot files

#### Generates GRUB boot images:
```bash
# BIOS boot image with all necessary modules
grub-mkstandalone --format=i386-pc \
    --output=boot/grub/core.img \
    --install-modules="linux normal iso9660 biosdisk memdisk search tar ls all_video gfxterm"

# Combine with boot sector
cat /usr/lib/grub/i386-pc/cdboot.img boot/grub/core.img > boot/grub/bios.img

# UEFI boot image
grub-mkstandalone --format=x86_64-efi \
    --output=EFI/boot/bootx64.efi
```

#### GRUB Configuration:
```
set timeout=10
set default=0

insmod all_video
insmod gfxterm
terminal_output gfxterm

menuentry "NubiferOS 1.0 - Live" {
    linux /boot/vmlinuz boot=live components quiet splash
    initrd /boot/initrd.img
}

menuentry "NubiferOS 1.0 - Live (Safe Mode)" {
    linux /boot/vmlinuz boot=live components nomodeset
    initrd /boot/initrd.img
}
```

Key boot parameters:
- `boot=live` - Activates live-boot scripts
- `components` - Loads all live-boot components
- `quiet splash` - Reduces boot messages and shows splash screen
- `nomodeset` - Safe mode disables kernel mode setting for compatibility

#### Creates FAT EFI boot partition:
```bash
# Create 10MB FAT image for EFI
dd if=/dev/zero of=boot/grub/efi.img bs=1M count=10
mkfs.vfat boot/grub/efi.img

# Mount and populate with EFI bootloader
mount -o loop boot/grub/efi.img /mnt
cp EFI/boot/bootx64.efi /mnt/EFI/boot/
umount /mnt
```

#### Generates hybrid ISO:
```bash
xorriso -as mkisofs \
    -iso-level 3 \
    -volid "NUBIFEROS-1.0" \
    # BIOS boot
    -eltorito-boot boot/grub/bios.img \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    --grub2-boot-info \
    --grub2-mbr /usr/lib/grub/i386-pc/boot_hybrid.img \
    # UEFI boot
    -eltorito-alt-boot \
    -e boot/grub/efi.img \
    -no-emul-boot \
    -append_partition 2 0xef boot/grub/efi.img \
    -partition_offset 16 \
    -output nubiferos.iso \
    iso/
```

### 3. Updated Dependencies

Added required tools to dependency checks:

**New dependencies:**
- `grub-mkstandalone` - Creates standalone GRUB images
- `mkfs.vfat` - Creates FAT filesystem for EFI partition (from `dosfstools`)

**Updated install command:**
```bash
sudo apt-get install -y debootstrap squashfs-tools xorriso \
    grub-pc-bin grub-efi-amd64-bin mtools dosfstools
```

## Boot Process

### BIOS Boot:
1. BIOS reads MBR (boot_hybrid.img)
2. Loads El Torito boot image (bios.img)
3. GRUB loads from boot/grub/grub.cfg
4. Boots kernel with initrd

### UEFI Boot:
1. UEFI firmware reads GPT partition table
2. Mounts EFI partition (efi.img)
3. Loads EFI/boot/bootx64.efi
4. GRUB loads from EFI/boot/grub.cfg
5. Boots kernel with initrd

## Testing

The ISO should now boot on:
- ✅ Legacy BIOS systems
- ✅ UEFI systems (with Secure Boot disabled)
- ✅ Hybrid systems
- ✅ VirtualBox (both BIOS and EFI modes)
- ✅ Physical hardware
- ✅ USB drives (hybrid MBR/GPT)

## References

- [GRUB Manual - Making a GRUB bootable CD-ROM](https://www.gnu.org/software/grub/manual/grub/html_node/Making-a-GRUB-bootable-CD_002dROM.html)
- [xorriso man page](https://www.gnu.org/software/xorriso/man_1_xorriso.html)
- [Debian Live Manual - Customizing the binary image](https://live-team.pages.debian.net/live-manual/html/live-manual/customizing-binary.en.html)
