# Calamares Segmentation Fault Fix

## Problem
Calamares crashes with "Segmentation fault" after checking battery/power status.

## Root Causes
1. **Power check in VMs** - The power/battery check can crash in virtual machines
2. **Missing QML modules** - Required Qt/QML libraries may be missing
3. **Branding configuration** - Malformed branding files can cause crashes
4. **Module configuration** - Invalid module configs trigger segfaults
5. **XDG_RUNTIME_DIR not set** - Qt applications need this environment variable set for root user

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

### 4. XDG_RUNTIME_DIR Configuration
Created `/etc/tmpfiles.d/xdg-runtime-root.conf` to ensure `/run/user/0` exists:
```
d /run/user/0 0700 root root -
```

This prevents the "QStandardPaths: XDG_RUNTIME_DIR not set" error that causes segfaults.

## Testing in Live Environment

If Calamares still crashes, try these commands:

```bash
# 1. Ensure XDG_RUNTIME_DIR exists for root
sudo mkdir -p /run/user/0
sudo chmod 700 /run/user/0

# 2. Check if all QML modules are present
dpkg -l | grep qml-module

# 3. Test Calamares with debug output and proper environment
sudo XDG_RUNTIME_DIR=/run/user/0 calamares -d 2>&1 | tee /tmp/calamares-debug.log

# 4. Check for missing libraries
ldd /usr/bin/calamares | grep "not found"

# 5. Try without branding
sudo XDG_RUNTIME_DIR=/run/user/0 calamares -d --config /etc/calamares/settings.conf

# 6. Check dmesg for crash details
dmesg | tail -20
```

## Workaround: Manual Launch

If autostart fails, manually launch with proper environment:
```bash
# Ensure runtime directory exists
sudo mkdir -p /run/user/0
sudo chmod 700 /run/user/0

# Launch with debug
sudo XDG_RUNTIME_DIR=/run/user/0 calamares -d
```

Or use the provided launch script:
```bash
./testing/launch-calamares.sh
```

Or the quick test script:
```bash
./testing/quick-calamares-test.sh
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
