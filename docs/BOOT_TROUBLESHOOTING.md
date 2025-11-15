# Boot Troubleshooting Guide

## Common Boot Issues and Solutions

### Issue 1: "Unexpected exception 14" or GRUB Crash

**Symptoms:**
- GRUB shows error like "Unexpected exception 14 @ 0x..."
- System crashes immediately after GRUB loads
- Error codes like "error code 0x0"

**Causes:**
- Missing GRUB modules (all_video, gfxterm)
- Missing live-boot packages in initramfs
- Incorrect GRUB configuration paths

**Solution:**
Ensure these packages are installed in the chroot:
```bash
# In install-desktop.sh
live-boot
live-boot-initramfs-tools
```

And GRUB config includes video modules:
```
insmod all_video
insmod gfxterm
terminal_output gfxterm
```

### Issue 2: "No bootable medium found"

**Symptoms:**
- BIOS/UEFI can't find boot device
- ISO doesn't appear in boot menu

**Causes:**
- Missing boot_hybrid.img in xorriso command
- Incorrect El Torito boot configuration
- Missing EFI partition

**Solution:**
Verify xorriso command includes:
```bash
--grub2-mbr /usr/lib/grub/i386-pc/boot_hybrid.img
-eltorito-boot boot/grub/bios.img
-e boot/grub/efi.img
```

### Issue 3: Kernel Panic - "not syncing: VFS: Unable to mount root fs"

**Symptoms:**
- Kernel loads but can't find root filesystem
- Error about mounting root fs
- Drops to initramfs shell

**Causes:**
- Missing live-boot in initramfs
- Squashfs not found or corrupted
- Wrong boot parameters

**Solution:**
1. Verify live-boot is installed before running `update-initramfs`
2. Check boot parameters include `boot=live`
3. Verify squashfs file exists at `/live/filesystem.squashfs`

### Issue 4: Black Screen After GRUB

**Symptoms:**
- GRUB menu appears and works
- After selecting boot option, screen goes black
- System appears to hang

**Causes:**
- Graphics driver issues
- Missing kernel modules
- Incorrect video mode

**Solution:**
Use safe mode boot option with `nomodeset`:
```
linux /boot/vmlinuz boot=live components nomodeset
```

Or add to GRUB config:
```
set gfxpayload=keep
```

### Issue 5: "Could not find kernel image: vmlinuz"

**Symptoms:**
- GRUB can't find kernel
- Error about missing vmlinuz or initrd.img

**Causes:**
- Kernel files not copied to ISO
- Wrong paths in GRUB config
- Kernel not installed in chroot

**Solution:**
1. Verify kernel is installed:
```bash
chroot_exec "apt-get install -y linux-image-amd64"
```

2. Verify files are copied:
```bash
cp "${CHROOT_DIR}/boot/vmlinuz-"* "${ISO_DIR}/boot/vmlinuz"
cp "${CHROOT_DIR}/boot/initrd.img-"* "${ISO_DIR}/boot/initrd.img"
```

3. Check GRUB paths are absolute from ISO root:
```
linux /boot/vmlinuz ...
initrd /boot/initrd.img
```

## VirtualBox Specific Issues

### Issue: EFI Boot Fails in VirtualBox

**Solution:**
1. Disable EFI in VM settings (use BIOS mode)
2. Or ensure EFI partition is properly formatted:
```bash
mkfs.vfat -F 32 efi.img
```

### Issue: "FATAL: No bootable medium found!"

**Solution:**
1. Verify ISO is attached to VM
2. Check boot order in VM settings
3. Try both BIOS and EFI modes

## Testing Boot Configuration

### Test BIOS Boot:
```bash
qemu-system-x86_64 \
    -cdrom nubiferos.iso \
    -m 4096 \
    -boot d
```

### Test UEFI Boot:
```bash
qemu-system-x86_64 \
    -cdrom nubiferos.iso \
    -m 4096 \
    -bios /usr/share/ovmf/OVMF.fd \
    -boot d
```

### Verify ISO Structure:
```bash
# Mount ISO and check structure
mkdir -p /mnt/iso
mount -o loop nubiferos.iso /mnt/iso

# Should contain:
ls -la /mnt/iso/boot/grub/bios.img
ls -la /mnt/iso/boot/grub/efi.img
ls -la /mnt/iso/boot/vmlinuz
ls -la /mnt/iso/boot/initrd.img
ls -la /mnt/iso/live/filesystem.squashfs
ls -la /mnt/iso/EFI/boot/bootx64.efi

umount /mnt/iso
```

## Debug Mode

To enable verbose boot output, modify GRUB config:

```
menuentry "NubiferOS - Debug Mode" {
    linux /boot/vmlinuz boot=live components debug
    initrd /boot/initrd.img
}
```

This will show detailed boot messages instead of splash screen.

## Getting Help

If boot issues persist:

1. Check build logs for errors during ISO creation
2. Verify all dependencies are installed on build system
3. Test ISO in multiple environments (QEMU, VirtualBox, physical hardware)
4. Check that squashfs was created successfully
5. Verify initramfs includes live-boot hooks:
   ```bash
   lsinitramfs initrd.img | grep live
   ```
