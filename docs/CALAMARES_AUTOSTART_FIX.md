# Calamares Autostart Fix

## Problem

When booting the live ISO, Calamares may fail to auto-start with errors like:
- `xdg-user-dir not found`
- `mkdir missing operand`
- `chmod cannot access /install-debian-desktop - no such file or directory`
- `QStandardPaths: XDG_RUNTIME_DIR not set, defaulting to '/tmp/runtime-root'`
- `Segmentation fault`

## Root Causes

1. **XDG_RUNTIME_DIR not created** - The `/run/user/1000` directory for the live user doesn't exist
2. **Broken desktop icon service** - Debian's default Calamares package may include a broken desktop icon service
3. **Race condition** - Calamares tries to start before the runtime directory is ready
4. **Missing environment variables** - Qt applications need proper environment setup

## Fixes Applied

### 1. Systemd Tmpfiles Configuration ✅

Created `/etc/tmpfiles.d/xdg-runtime-root.conf` to ensure runtime directories exist:

```
d /run/user/0 0700 root root -
d /run/user/1000 0700 live live -
```

This creates runtime directories for both root and the live user on boot.

### 2. Updated Autostart Service ✅

Modified `build/configure-installer-autostart.sh` to ensure the runtime directory exists before launching:

```ini
[Service]
Type=simple
User=live
Environment=DISPLAY=:0
Environment=XDG_RUNTIME_DIR=/run/user/1000
# Ensure XDG_RUNTIME_DIR exists before launching
ExecStartPre=/bin/mkdir -p /run/user/1000
ExecStartPre=/bin/chown live:live /run/user/1000
ExecStartPre=/bin/chmod 700 /run/user/1000
ExecStartPre=/bin/sleep 5
ExecStart=/usr/bin/pkexec /usr/bin/calamares -d
```

### 3. Updated Launch Scripts ✅

Both `testing/launch-calamares.sh` and `testing/quick-calamares-test.sh` now:
- Create `/run/user/0` if it doesn't exist
- Set `XDG_RUNTIME_DIR` environment variable
- Use a wrapper script to ensure proper environment

## Testing in Live Environment

### Quick Test

```bash
# Run the diagnostic tool
./testing/diagnose-calamares-full.sh

# If issues found, manually create runtime directories
sudo mkdir -p /run/user/0
sudo chmod 700 /run/user/0
mkdir -p /run/user/1000
chmod 700 /run/user/1000

# Launch Calamares
./testing/launch-calamares.sh
```

### Manual Launch

If autostart fails:

```bash
# Ensure runtime directories exist
sudo mkdir -p /run/user/0
sudo chmod 700 /run/user/0

# Launch with proper environment
sudo XDG_RUNTIME_DIR=/run/user/0 calamares -d
```

### Check Systemd Service Status

```bash
# Check if service is running
systemctl status calamares-autostart.service

# View service logs
journalctl -u calamares-autostart.service -f

# Restart service if needed
sudo systemctl restart calamares-autostart.service
```

## Disabling Broken Desktop Icon Service

If you see errors about `calamares-desktop-icon.desktop`, this is from Debian's package. To disable it:

```bash
# Find the service
systemctl list-units | grep calamares

# Disable it
sudo systemctl disable calamares-desktop-icon.service
sudo systemctl mask calamares-desktop-icon.service
```

## Rebuilding ISO

After making these changes, rebuild the ISO:

```bash
sudo ./build-nubiferos.sh
```

The new ISO will include:
- Tmpfiles configuration for runtime directories
- Updated autostart service with proper environment
- All necessary QML dependencies

## Verification

After booting the new ISO:

1. Check runtime directories exist:
   ```bash
   ls -la /run/user/0
   ls -la /run/user/1000
   ```

2. Check Calamares service:
   ```bash
   systemctl status calamares-autostart.service
   ```

3. Check for errors:
   ```bash
   journalctl -xe | grep calamares
   ```

4. Calamares should auto-launch within 5-10 seconds of desktop appearing

## Related Files

- `configs/system/xdg-runtime-root.conf` - Tmpfiles configuration
- `build/configure-installer-autostart.sh` - Autostart service configuration
- `testing/launch-calamares.sh` - Manual launcher with environment setup
- `testing/quick-calamares-test.sh` - Quick test script
- `testing/diagnose-calamares-full.sh` - Comprehensive diagnostic tool
- `build/build-iso.sh` - Includes tmpfiles config in ISO

## Troubleshooting

### Calamares doesn't start automatically

1. Check if service is enabled:
   ```bash
   systemctl is-enabled calamares-autostart.service
   ```

2. Check service status:
   ```bash
   systemctl status calamares-autostart.service
   ```

3. Try manual launch:
   ```bash
   ./testing/launch-calamares.sh
   ```

### Segmentation fault on launch

1. Ensure XDG_RUNTIME_DIR exists:
   ```bash
   sudo mkdir -p /run/user/0
   sudo chmod 700 /run/user/0
   ```

2. Check QML modules are installed:
   ```bash
   dpkg -l | grep qml-module
   ```

3. Run with debug output:
   ```bash
   sudo XDG_RUNTIME_DIR=/run/user/0 calamares -d
   ```

### Service fails with "couldn't move process to cgroup"

This is usually harmless and doesn't prevent Calamares from launching. It's a systemd warning about cgroup management.

## Alternative: Disable Autostart

If autostart continues to cause issues, you can disable it and launch manually:

```bash
# Disable autostart
sudo systemctl disable calamares-autostart.service

# Launch manually when needed
./testing/launch-calamares.sh
```
