# CRITICAL: Bootloader Installation Fails Due to Overlay Filesystem

**Date Discovered**: 2026-01-19  
**Severity**: CRITICAL - Blocks all installations  
**Root Cause**: Live CD overlay filesystem prevents grub-install from working  
**Status**: ✅ ROOT CAUSE IDENTIFIED, WORKAROUND CONFIRMED

---

## The Problem

For weeks, bootloader installation was failing with various errors:
- `grub-install: error: failed to get canonical path of '/boot/efi'`
- `grub-install: error: failed to get canonical path of 'overlay'`
- Command returns error code 1

We thought it was a `--force` flag issue, but that was a red herring.

## The Real Root Cause

**The live CD uses an overlay filesystem**, and grub-install cannot resolve canonical paths through overlay filesystems. This is a fundamental limitation.

### Why It Fails

1. Live CD boots with `boot=live` parameter
2. System uses overlay filesystem (tmpfs + squashfs)
3. Calamares creates a chroot in the overlay environment
4. When grub-install runs, it tries to resolve paths like `/boot/efi`
5. The overlay filesystem confuses path resolution
6. grub-install fails with "cannot get canonical path" errors

### Evidence

```bash
# Inside Calamares chroot during installation:
$ df -T /
Filesystem    Type     Mounted on
overlay       overlay  /

# This is the problem - grub-install can't work with overlay
```

## The Solution That Works

### Manual Installation Method (CONFIRMED WORKING)

```bash
# 1. Exit Calamares chroot
exit

# 2. Mount the installed system properly (no overlay)
sudo mkdir -p /mnt/installed
sudo mount /dev/sda2 /mnt/installed
sudo mount /dev/sda1 /mnt/installed/boot/efi

# 3. Bind mount necessary filesystems
sudo mount --bind /dev /mnt/installed/dev
sudo mount --bind /proc /mnt/installed/proc
sudo mount --bind /sys /mnt/installed/sys
sudo mount --bind /run /mnt/installed/run

# 4. Chroot into the REAL filesystem (not overlay)
sudo chroot /mnt/installed

# 5. Install GRUB (THIS WORKS!)
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=nubiferos --no-nvram --removable

# 6. Generate GRUB config
grub-mkconfig -o /boot/grub/grub.cfg

# 7. Exit and reboot
exit
sudo reboot
```

**Result**: ✅ System boots successfully!

## Why This Works

- Real filesystem (ext4) instead of overlay
- grub-install can resolve canonical paths
- No overlay confusion
- Standard chroot environment

## The `--force` Red Herring

We spent weeks thinking `--force` was the problem because:
1. Error messages showed commands with `--force`
2. We removed `--force` from all configs
3. But it kept appearing in error messages

**The truth**: Calamares or grub-install was adding `--force` automatically when the first attempt failed. The `--force` flag was a symptom, not the cause.

## Implications

### Short-term Fix Needed

Calamares needs to:
1. Ensure `/boot/efi` directory exists before mounting
2. Use a proper chroot (not overlay-based) for bootloader installation
3. OR: Run bootloader installation outside the overlay environment

### Long-term Solution (REQUIRED FOR SECURITY)

**Remove the live CD entirely** - See `docs/guides/TODO_REMOVE_LIVE_CD.md`

The live CD is:
- ❌ A security vulnerability (bypasses encryption)
- ❌ Causing this bootloader issue
- ❌ Creating the "installer" user in installed systems
- ❌ Blocking Alpha release

Moving to installer-only ISO will:
- ✅ Fix bootloader installation (no overlay)
- ✅ Fix security issues
- ✅ Simplify the boot process
- ✅ Remove auto-login issues

## Additional Issues Found

### Missing `/boot/efi` Directory

Even in proper chroot, `/boot/efi` directory didn't exist initially. The partition was mounted, but the mount point was invisible because the directory didn't exist in the filesystem.

**Fix**: Ensure `/boot/efi` directory is created during system installation before mounting the EFI partition.

### Installer User in Installed System

The "installer" user from the live CD is being copied to the installed system. This shouldn't happen.

**Fix**: Calamares should exclude live CD users from the installed system.

## Testing Checklist

To verify bootloader installation works:

- [ ] Boot from ISO
- [ ] Run installation
- [ ] Check if `/boot/efi` exists in installed system
- [ ] Verify grub-install runs without overlay errors
- [ ] Verify system boots after installation
- [ ] Verify no "installer" user in installed system
- [ ] Verify only user-created accounts exist

## Files to Modify

### Immediate Fixes
- `installer/calamares/modules/prepare-bootloader.conf` - Create `/boot/efi` directory
- `installer/calamares/modules/bootloader.conf` - Ensure proper chroot or run outside overlay
- `build/install-desktop-installer.sh` - Ensure `/boot/efi` exists in base system

### Long-term (Remove Live CD)
- `build/install-desktop.sh` - Remove live-boot packages
- `build/build-iso.sh` - Remove `boot=live` parameter
- `build/build-iso.sh` - Remove live user creation
- See full checklist in `docs/guides/TODO_REMOVE_LIVE_CD.md`

## Timeline

1. **Immediate** (This Week):
   - Document this discovery ✅
   - Create workaround for manual installation ✅
   - Fix Calamares to use proper chroot

2. **Short-term** (Next Sprint):
   - Fix `/boot/efi` directory creation
   - Remove installer user from installed systems
   - Test automated installation works

3. **Before Alpha Release** (REQUIRED):
   - Remove live CD entirely
   - Implement installer-only ISO
   - Verify security requirements met

## Related Documentation

- `docs/guides/TODO_REMOVE_LIVE_CD.md` - Security requirements
- `docs/KNOWN_ISSUES.md` - Known issues list
- `docs/THREAT_MODEL.md` - Security model
- `installer/calamares/modules/bootloader.conf` - Current config

## Key Takeaways

1. **The overlay filesystem is the root cause** - Not `--force`, not device paths, not UEFI vs BIOS
2. **Manual installation works** - Proves the concept and flags are correct
3. **Live CD must be removed** - It's both a security issue and technical blocker
4. **Proper chroot is essential** - Calamares needs to use real filesystem, not overlay

---

**Status**: 🟢 ROOT CAUSE IDENTIFIED  
**Next Steps**: Fix Calamares bootloader installation, then remove live CD  
**Blocking**: Alpha release until live CD is removed

**Last Updated**: 2026-01-19  
**Discovered By**: Debugging session after weeks of investigation
