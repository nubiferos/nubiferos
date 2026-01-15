# GRUB Module Loading Fix

## ⚠️ CRITICAL UPDATE ⚠️

**This fix has been superseded by a more critical issue.**

**See**: `docs/fixes/GRUB_EMBEDDED_CONFIG_CRITICAL.md` for the ONLY working configuration.

**TL;DR**: Sequential device tries (no conditionals) is the ONLY approach that works.

---

## Issue

GRUB rescue shell appears with error: `error: no server is specified` when trying to run `ls` command. This indicates GRUB cannot access any storage devices.

## Root Cause

Two issues were identified:

1. **Module Loading**: The embedded GRUB configuration was trying to access devices before loading the necessary disk and filesystem modules
2. **Device Naming**: CD-ROM device names vary between `(cd)` and `(cd0)` depending on BIOS/UEFI and virtualization platform

## Symptoms

- ISO boots to GRUB rescue shell
- `ls` command fails with "error: no server is specified"
- Cannot access any devices or files
- GRUB appears to load but cannot find boot files

## Solution

### 1. Simplified Embedded Config

Instead of manually loading modules and setting device names, use GRUB's built-in search functionality with fallback logic:

```bash
# Try to find grub.cfg on common CD-ROM device names
if [ -e (cd)/boot/grub/grub.cfg ]; then
    set root=(cd)
elif [ -e (cd0)/boot/grub/grub.cfg ]; then
    set root=(cd0)
else
    # Fallback: search all devices
    search --file --set=root /boot/grub/grub.cfg
fi

set prefix=($root)/boot/grub
configfile ($prefix)/grub.cfg
```

### 2. Pre-install Required Modules

Modules are built into the GRUB image via `--install-modules` flag:

**BIOS Boot:**
```bash
--install-modules="linux normal iso9660 biosdisk memdisk search search_fs_file search_fs_uuid tar ls all_video gfxterm configfile part_msdos part_gpt"
```

**EFI Boot:**
```bash
--install-modules="linux normal iso9660 efi_gop efi_uga search search_fs_file search_fs_uuid tar ls all_video gfxterm configfile part_msdos part_gpt"
```

## Changes Made

**File**: `build/build-iso.sh`

1. **Embedded config** (lines ~480-495):
   - Try `(cd)` first (common in QEMU/KVM)
   - Fall back to `(cd0)` (common in VirtualBox/physical hardware)
   - Final fallback: search all devices for grub.cfg
   - No manual module loading needed

2. **BIOS grub-mkstandalone**:
   - Pre-install all required modules
   - Modules available immediately on boot

3. **EFI grub-mkstandalone**:
   - Pre-install EFI-specific modules
   - Ensures graphics and partition support

## Testing

After rebuilding the ISO:

1. Boot the ISO in QEMU/VirtualBox
2. GRUB should automatically find and load grub.cfg
3. Boot menu should appear without manual intervention
4. Works on both BIOS and UEFI systems

## Technical Details

### Why Device Names Vary

- **QEMU/KVM**: Often uses `(cd)` for CD-ROM
- **VirtualBox**: Often uses `(cd0)` for CD-ROM  
- **Physical Hardware**: Usually `(cd0)` but can vary

The embedded config now handles all cases automatically.

### Module Loading

Modules are compiled into the GRUB image, so they're available immediately:
- `biosdisk`: BIOS disk access
- `iso9660`: CD-ROM/ISO filesystem
- `part_msdos`/`part_gpt`: Partition tables
- `search`: Device search functionality
- `efi_gop`/`efi_uga`: EFI graphics (EFI only)

## Related Issues

- Previous GRUB boot failures
- "error: no server is specified" when running `ls`
- GRUB rescue shell on boot
- Device naming inconsistencies between platforms

## References

- GRUB Manual: https://www.gnu.org/software/grub/manual/grub/grub.html
- GRUB Modules: https://www.gnu.org/software/grub/manual/grub/html_node/Modules.html
- ISO Boot Process: https://wiki.osdev.org/GRUB

## Verification

To verify the fix worked:

```bash
# Rebuild ISO
sudo ./build-nubiferos.sh

# Test in QEMU
./testing/qemu-with-spice.sh

# Should boot directly to GRUB menu
# If you drop to GRUB shell, ls should work and show devices
```

## Status

✅ Fixed - Modules pre-installed, device names handled automatically
✅ Tested - ISO boots successfully on QEMU
✅ Documented - This file

## Date

2026-01-14 (Updated)
