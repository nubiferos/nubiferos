# Calamares Segmentation Fault Fix

## Problem
Calamares crashes with "Segmentation fault" after checking battery/power status.

## Root Causes
1. **Power check in VMs** - The power/battery check can crash in virtual machines
2. **Missing QML modules** - Required Qt/QML libraries may be missing
3. **Branding configuration** - Malformed branding files can cause crashes
4. **Module configuration** - Invalid module configs trigger segfaults

## Fixes Applied

### 1. Disabled Problematic Checks
Updated `installer/calamares/modules/welcome.conf`:
- Removed `power` check (causes crashes in VMs)
- Removed `internet` check (not critical for installation)
- Kept only: storage, ram, root

### 2. Ensure QML Dependencies
The build script should install:
```bash
calamares
calamares-settings-debian
qml-module-qtquick2
qml-module-qtquick-controls
qml-module-qtquick-layouts
qml-module-qtquick-window2
```

### 3. Simplified Branding
- Minimal QML slideshow
- No complex animations
- Basic text and colors only

## Testing in Live Environment

If Calamares still crashes, try these commands:

```bash
# 1. Check if all QML modules are present
dpkg -l | grep qml-module

# 2. Test Calamares with debug output
calamares -d 2>&1 | tee /tmp/calamares-debug.log

# 3. Check for missing libraries
ldd /usr/bin/calamares | grep "not found"

# 4. Try without branding
sudo calamares -d --config /etc/calamares/settings.conf

# 5. Check dmesg for crash details
dmesg | tail -20
```

## Workaround: Manual Launch

If autostart fails, manually launch:
```bash
sudo calamares -d
```

Or without debug:
```bash
sudo calamares
```

## Permanent Fix for Next Build

Update `build/install-calamares.sh` to ensure all dependencies:

```bash
chroot_exec "DEBIAN_FRONTEND=noninteractive apt-get install -y \
    calamares \
    calamares-settings-debian \
    qml-module-qtquick2 \
    qml-module-qtquick-controls \
    qml-module-qtquick-controls2 \
    qml-module-qtquick-layouts \
    qml-module-qtquick-window2 \
    qml-module-qtquick-dialogs \
    qml-module-qtgraphicaleffects \
    libkf5config-bin \
    libkf5coreaddons5 \
    libkpmcore12"
```

## Known Issues

### VirtualBox
- Power checks may fail
- Use `check: [storage, ram, root]` only

### QEMU/KVM  
- Usually works fine
- May need `-enable-kvm` flag

### VMware
- Similar to VirtualBox
- Disable power checks

## Alternative: Use Debian Installer

If Calamares continues to crash, consider using the standard Debian installer (d-i) instead:
- More stable
- Better VM support
- Less graphical, but reliable

## Next Steps

1. Rebuild ISO with updated welcome.conf
2. Test in VirtualBox
3. If still crashes, add more QML dependencies
4. Consider switching to d-i if issues persist
