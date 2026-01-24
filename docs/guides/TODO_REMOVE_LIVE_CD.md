# Live CD Removal - COMPLETED

## Status: ✅ COMPLETED (January 2026)

The live CD functionality has been removed from NubiferOS to prevent security bypasses.

## Changes Made

### 1. Removed Live Boot Options
- [x] Removed `--live` and `--mode` options from `build-iso.sh`
- [x] Deleted `install-desktop-live.sh` (live environment setup)
- [x] Deleted `install-desktop.sh` (old duplicate file)
- [x] Removed live user creation code
- [x] GRUB now only shows "Install" options (no "Live" mode)

### 2. Installer-Only ISO
- [x] ISO boots directly to installer user
- [x] Calamares auto-starts on login
- [x] LUKS encryption pre-checked (strongly encouraged)
- [x] LUKS1 for GRUB compatibility

### 3. Security Model
- ISO boots using `boot=live` (required for squashfs boot mechanism)
- BUT: No live desktop environment - only installer
- installer user auto-logs in → Calamares auto-starts
- No way to access files without completing installation

## Technical Note
The `boot=live` kernel parameter is still used because that's how the initramfs knows to mount the squashfs filesystem instead of looking for a real partition. This is a technical requirement for any ISO-based boot, not a security concern. The security comes from:
1. Only the "installer" user exists (no "live" user)
2. GDM auto-logs in to the installer user
3. Calamares auto-starts and is the only thing users can interact with

## Files Modified
- `build/build-iso.sh` - Removed live mode options
- `build/install-desktop-installer.sh` - Already existed, now the only desktop script

## Files Deleted
- `build/install-desktop-live.sh`
- `build/install-desktop.sh`

---

**Status**: ✅ COMPLETED
**Completed**: January 2026
