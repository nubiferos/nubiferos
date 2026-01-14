# Calamares Quick Fix Reference

## Problem: Calamares crashes with "XDG_RUNTIME_DIR not set" → Segmentation fault

## Immediate Fix (In Live Environment)

```bash
# 1. Create runtime directories
sudo mkdir -p /run/user/0
sudo chmod 700 /run/user/0

# 2. Launch Calamares
sudo XDG_RUNTIME_DIR=/run/user/0 calamares
```

## Or Use Our Scripts

```bash
# Quick test
./testing/quick-calamares-test.sh

# Full launcher
./testing/launch-calamares.sh

# Diagnostics
./testing/diagnose-calamares-full.sh
```

## Permanent Fix (Rebuild ISO)

```bash
sudo ./build-nubiferos.sh
```

The rebuild includes:
- ✅ Tmpfiles config for runtime directories
- ✅ Updated autostart service
- ✅ All QML dependencies
- ✅ Disabled problematic power checks

## Check If Fixed

```bash
# Should show directories
ls -la /run/user/0
ls -la /run/user/1000

# Should show service running
systemctl status calamares-autostart.service

# Should show no errors
journalctl -xe | grep calamares | tail -20
```

## Files Changed

- `configs/system/xdg-runtime-root.conf` - NEW
- `build/configure-installer-autostart.sh` - UPDATED
- `build/build-iso.sh` - UPDATED
- `testing/launch-calamares.sh` - UPDATED
- `testing/quick-calamares-test.sh` - UPDATED

## Full Documentation

- `CALAMARES_COMPLETE_FIX.md` - Complete fix summary
- `docs/XDG_RUNTIME_DIR_FIX.md` - XDG_RUNTIME_DIR details
- `docs/CALAMARES_AUTOSTART_FIX.md` - Autostart issues
- `docs/CALAMARES_SEGFAULT_FIX.md` - General troubleshooting
