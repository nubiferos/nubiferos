# Calamares 3.3.8 Upgrade

## Problem

Calamares 3.2.61 (Debian Bookworm default) has a known QML threading bug that causes segfaults in VMs:
```
QThread::setPriority: Cannot set priority, thread is not running
Segmentation fault
```

## Solution

Upgrade to Calamares 3.3.8 from Debian Bookworm Backports.

## Changes Made

**File:** `build/install-calamares.sh`

1. Added bookworm-backports repository
2. Install Calamares 3.3.8 using `-t bookworm-backports`
3. Removed `calamares-settings-debian` (not needed for 3.3.x)

## Benefits of 3.3.8

- Fixed QML threading issues
- Better VM support
- Improved stability
- Modern Qt5 support
- Active maintenance

## Testing

```bash
# Rebuild ISO
sudo ./build-nubiferos.sh

# Test in QEMU
./testing/qemu-with-spice.sh

# Check version in VM
calamares --version
# Should show: calamares 3.3.8
```

## Rollback

If 3.3.8 has issues, revert `build/install-calamares.sh` to install from main repos:

```bash
git diff build/install-calamares.sh
git checkout build/install-calamares.sh
```

## Next Steps

If 3.3.8 still segfaults:
- Switch to Debian Installer (d-i)
- See `CALAMARES_DECISION.md` for implementation guide
