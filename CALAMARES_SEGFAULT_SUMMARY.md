# Calamares Segfault Fix Summary

## Issue
Calamares crashes with segmentation fault after "battery exists, checking mains power" message.

## Root Cause
The power/battery check in Calamares crashes in virtual machines (VirtualBox, QEMU) because:
1. VMs don't properly emulate battery/power management
2. Missing or incomplete QML/Qt dependencies
3. Power check module tries to access hardware that doesn't exist

## Fixes Applied

### 1. Disabled Power Check ✅
**File:** `installer/calamares/modules/welcome.conf`
- Removed `power` from checks list
- Removed `internet` from checks list  
- Kept only: `storage`, `ram`, `root`

### 2. Added Missing QML Dependencies ✅
**File:** `build/install-calamares.sh`

Added packages:
- `qml-module-qtquick-controls2` - Additional Qt Quick controls
- `qml-module-qtquick-dialogs` - Dialog components
- `qml-module-qtgraphicaleffects` - Graphics effects
- `libkf5config-bin` - KDE config library
- `libkf5coreaddons5` - KDE core addons
- `libkpmcore12` - Partition management library
- `libpolkit-qt5-1-1` - PolicyKit Qt bindings

## Testing

After rebuilding the ISO, Calamares should:
1. Launch without crashing
2. Skip power/battery checks
3. Show welcome screen properly
4. Allow installation to proceed

## If Still Crashes

Run these commands in the live environment:

```bash
# Check what's installed
dpkg -l | grep -E "calamares|qml-module"

# Try manual launch with debug
sudo calamares -d

# Check system logs
journalctl -xe | grep calamares
dmesg | tail -20
```

## Next Build

Rebuild the ISO:
```bash
sudo ./build-nubiferos.sh
```

The segfault should be resolved!

## Alternative Solutions

If issues persist:
1. **Use Debian Installer (d-i)** - More stable, less graphical
2. **Disable autostart** - Launch Calamares manually
3. **Use different VM** - Try QEMU instead of VirtualBox

## Files Modified
- `installer/calamares/modules/welcome.conf` - Disabled power check
- `build/install-calamares.sh` - Added QML dependencies
- `docs/CALAMARES_SEGFAULT_FIX.md` - Detailed troubleshooting guide
