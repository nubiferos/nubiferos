# Calamares Segfault Fix Summary

## Issue
Calamares crashes with segmentation fault after "battery exists, checking mains power" message.

## Root Cause
The power/battery check in Calamares crashes in virtual machines (VirtualBox, QEMU) because:
1. VMs don't properly emulate battery/power management
2. Missing or incomplete QML/Qt dependencies
3. Power check module tries to access hardware that doesn't exist
4. **XDG_RUNTIME_DIR not set for root user** - Qt applications crash without this

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

### 3. Fixed XDG_RUNTIME_DIR for Root ✅
**File:** `configs/system/xdg-runtime-root.conf`

Created systemd tmpfiles configuration to ensure `/run/user/0` exists:
```
d /run/user/0 0700 root root -
```

This prevents the "QStandardPaths: XDG_RUNTIME_DIR not set" error that causes Qt applications to crash when running as root.

**Updated Scripts:**
- `testing/launch-calamares.sh` - Creates runtime dir and sets environment
- `testing/quick-calamares-test.sh` - Ensures runtime dir exists before launch
- `build/build-iso.sh` - Installs tmpfiles config in ISO

## Testing

After rebuilding the ISO, Calamares should:
1. Launch without crashing
2. Skip power/battery checks
3. Show welcome screen properly
4. Allow installation to proceed

## If Still Crashes

Run these commands in the live environment:

```bash
# Ensure XDG_RUNTIME_DIR exists
sudo mkdir -p /run/user/0
sudo chmod 700 /run/user/0

# Check what's installed
dpkg -l | grep -E "calamares|qml-module"

# Try manual launch with debug and proper environment
sudo XDG_RUNTIME_DIR=/run/user/0 calamares -d

# Or use the provided scripts
./testing/launch-calamares.sh
./testing/quick-calamares-test.sh

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
- `configs/system/xdg-runtime-root.conf` - **NEW** Systemd tmpfiles config for XDG_RUNTIME_DIR
- `build/build-iso.sh` - Installs tmpfiles config
- `testing/launch-calamares.sh` - Updated with XDG_RUNTIME_DIR fix
- `testing/quick-calamares-test.sh` - Updated with XDG_RUNTIME_DIR fix
- `docs/CALAMARES_SEGFAULT_FIX.md` - Detailed troubleshooting guide
- `docs/XDG_RUNTIME_DIR_FIX.md` - **NEW** Specific guide for XDG_RUNTIME_DIR issue
