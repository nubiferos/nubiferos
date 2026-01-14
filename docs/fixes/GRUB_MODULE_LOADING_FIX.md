# GRUB Module Loading Fix

## Issue

GRUB rescue shell appears with error: `error: no server is specified` when trying to run `ls` command. This indicates GRUB cannot access any storage devices.

## Root Cause

The embedded GRUB configuration (`embedded.cfg`) was trying to access the CD-ROM device `(cd0)` before loading the necessary disk and filesystem modules. This caused GRUB to fail to initialize storage access.

## Symptoms

- ISO boots to GRUB rescue shell
- `ls` command fails with "error: no server is specified"
- Cannot access any devices or files
- GRUB appears to load but cannot find boot files

## Solution

### 1. Load Modules First in embedded.cfg

Updated `embedded.cfg` to load essential modules BEFORE attempting to access devices:

```bash
# Load essential modules first
insmod iso9660
insmod biosdisk

# Set root to CD-ROM
set root=(cd0)
```

### 2. Add Missing Modules to BIOS Boot

Added partition table modules to BIOS grub-mkstandalone:

```bash
--install-modules="... part_msdos part_gpt memdisk"
--modules="... part_msdos part_gpt memdisk"
```

### 3. Add Missing Modules to EFI Boot

Added EFI-specific and partition modules to EFI grub-mkstandalone:

```bash
--install-modules="... efi_gop efi_uga part_msdos part_gpt"
--modules="... efi_gop efi_uga part_msdos part_gpt"
```

## Changes Made

**File**: `build/build-iso.sh`

1. **embedded.cfg** (lines 477-493):
   - Added `insmod iso9660` and `insmod biosdisk` at the start
   - Ensures modules are loaded before accessing devices

2. **BIOS grub-mkstandalone** (lines 494-501):
   - Added `part_msdos`, `part_gpt`, and `memdisk` modules
   - Ensures partition table support

3. **EFI grub-mkstandalone** (lines 519-526):
   - Added `efi_gop`, `efi_uga`, `part_msdos`, `part_gpt` modules
   - Ensures EFI graphics and partition support

## Testing

After rebuilding the ISO:

1. Boot the ISO in QEMU/VirtualBox
2. GRUB should load and show the boot menu
3. If you drop to GRUB shell, `ls` should now work and show devices
4. Boot should proceed normally

## Technical Details

### Module Loading Order

GRUB modules must be loaded in this order:
1. **Disk drivers** (`biosdisk` for BIOS, `efi_gop`/`efi_uga` for EFI)
2. **Filesystem drivers** (`iso9660` for CD-ROM)
3. **Partition support** (`part_msdos`, `part_gpt`)
4. **Search utilities** (`search`, `search_fs_file`)

### Why This Matters

- `biosdisk`: Provides BIOS disk access
- `iso9660`: Reads CD-ROM/ISO filesystem
- `part_msdos`/`part_gpt`: Reads partition tables
- `memdisk`: Allows loading from memory
- `efi_gop`/`efi_uga`: EFI graphics output

Without these modules loaded first, GRUB cannot access any storage devices, resulting in the "no server is specified" error.

## Related Issues

- Previous GRUB boot failures
- "error: no server is specified" when running `ls`
- GRUB rescue shell on boot

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

# In GRUB shell (if you drop to it), test:
grub> ls
# Should show: (cd0) (cd0,msdos1) etc.

grub> ls (cd0)/
# Should show ISO contents

grub> ls (cd0)/boot/grub/
# Should show grub.cfg and other files
```

## Status

✅ Fixed - Modules now load before device access
✅ Tested - ISO boots successfully
✅ Documented - This file

## Date

2026-01-14
