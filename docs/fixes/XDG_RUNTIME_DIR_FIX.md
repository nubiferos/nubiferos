# XDG_RUNTIME_DIR Fix for Calamares

## The Problem

When launching Calamares with `pkexec` or `sudo`, you may see:
```
QStandardPaths: XDG_RUNTIME_DIR not set, defaulting to '/tmp/runtime-root'
Segmentation fault
```

## Why This Happens

Qt applications (like Calamares) require the `XDG_RUNTIME_DIR` environment variable to be set. When running as root via `pkexec`, this directory (`/run/user/0`) doesn't exist by default, causing Qt to crash.

## Quick Fix (Immediate)

Run these commands before launching Calamares:

```bash
# Create the runtime directory for root
sudo mkdir -p /run/user/0
sudo chmod 700 /run/user/0

# Launch Calamares with the environment variable set
sudo XDG_RUNTIME_DIR=/run/user/0 calamares
```

Or use our provided scripts:

```bash
# Automated launch with all fixes
./testing/launch-calamares.sh

# Quick test
./testing/quick-calamares-test.sh
```

## Permanent Fix (In ISO)

The ISO build now includes a systemd tmpfiles configuration that automatically creates this directory on boot.

File: `/etc/tmpfiles.d/xdg-runtime-root.conf`
```
d /run/user/0 0700 root root -
```

This ensures `/run/user/0` exists whenever the system boots, preventing the crash.

## How It's Applied

1. **During ISO Build**: The `build/build-iso.sh` script copies `configs/system/xdg-runtime-root.conf` to `/etc/tmpfiles.d/`

2. **On Boot**: systemd-tmpfiles automatically creates `/run/user/0` with correct permissions

3. **When Launching**: Calamares (or any Qt app running as root) can use this directory

## Testing

After rebuilding the ISO with this fix:

```bash
# Boot the live environment
# Check if the directory exists
ls -la /run/user/0

# Should show:
# drwx------ 2 root root 40 Nov 23 12:34 /run/user/0

# Launch Calamares - should work without errors
pkexec calamares
```

## Related Files

- `configs/system/xdg-runtime-root.conf` - Tmpfiles configuration
- `testing/launch-calamares.sh` - Automated launcher with environment setup
- `testing/quick-calamares-test.sh` - Quick test script
- `build/build-iso.sh` - Includes this fix in ISO build
- `docs/CALAMARES_SEGFAULT_FIX.md` - Complete Calamares troubleshooting guide

## Additional Notes

This fix applies to any Qt application that needs to run as root, not just Calamares. If you encounter similar issues with other Qt apps, the same solution applies.
