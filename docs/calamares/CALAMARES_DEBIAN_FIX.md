# Calamares Debian Issues Fix

## Problem

When booting the NubiferOS ISO, journalctl showed these errors:

```
add-calamares-desktop-icon user-dir not found
cp missing declaration file operand usr/share/applications/install-debian.desktop
chmod: cannot access /install-debian.desktop, no such file or directory
```

## Root Cause

The `calamares-settings-debian` package includes a script (`add-calamares-desktop-icon`) that:

1. Tries to run `xdg-user-dirs-update` to create user directories
2. Attempts to copy `/usr/share/applications/install-debian.desktop` to `~/Desktop`
3. Tries to make it executable

This fails because:
- The Desktop directory doesn't exist in the live environment yet
- The `install-debian.desktop` file doesn't exist (we use our own Calamares configuration)
- The script runs before XDG directories are properly initialized

## Solution

Created `build/fix-calamares-debian-issues.sh` which:

1. **Replaces the problematic script** with a safe no-op version
   - Backs up original to `/usr/bin/add-calamares-desktop-icon.orig`
   - Creates new version that exits cleanly

2. **Ensures XDG directories exist**
   - Installs `xdg-user-dirs` package
   - Runs `xdg-user-dirs-update` for live user
   - Creates Desktop directory with proper ownership

3. **Removes conflicting files**
   - Removes `install-debian.desktop` if present
   - Disables any related systemd services

4. **Integrated into build process**
   - Runs after Calamares installation (Step 6.5)
   - Before autostart configuration (Step 6.6)

## Files Modified

- `build/build-iso.sh` - Added fix script to build sequence
- `build/fix-calamares-debian-issues.sh` - New fix script (created)

## Testing

After rebuilding the ISO:
1. Boot in QEMU: `./testing/qemu-with-spice.sh`
2. Check journalctl: `journalctl -xe | grep calamares`
3. Should see no errors about `add-calamares-desktop-icon` or `install-debian.desktop`

## Related Fixes

This also addresses:
- SPICE clipboard support (added `spice-vdagent` in `build/install-desktop.sh`)
- Proper XDG directory initialization for live user
- Clean Calamares autostart without Debian-specific interference
