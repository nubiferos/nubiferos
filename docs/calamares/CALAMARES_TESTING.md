# Calamares Installer Testing Guide

## Overview

This guide explains how to test and troubleshoot the Calamares installer in NubiferOS.

## Current Configuration

### User Accounts

The live ISO creates a **live** user (not "installer"):
- Username: `live`
- Password: See `docs/guides/LIVE_USER_EXPLANATION.md`
- Auto-login: Enabled
- Sudo access: Yes

### Autostart Configuration

Calamares is configured to launch automatically when the live user logs in via:
- `/etc/skel/.config/autostart/calamares.desktop`
- Copied to `/home/live/.config/autostart/calamares.desktop`

## Testing the Installer

### Method 1: Use the Test Script

Run the provided test script to verify the Calamares configuration:

```bash
# Inside the live environment
./testing/test-calamares.sh
```

This script will:
1. Check if Calamares is installed
2. Verify configuration files exist
3. Check for autostart configuration
4. Optionally launch Calamares manually

### Method 2: Manual Launch

If autostart doesn't work, you can launch Calamares manually:

```bash
# From terminal
pkexec calamares

# Or with sudo
sudo calamares
```

### Method 3: Check from Applications Menu

Calamares should appear in the GNOME applications menu under "System" category.

## Troubleshooting

### Calamares Doesn't Launch Automatically

**Check 1: Verify autostart file exists**
```bash
ls -la ~/.config/autostart/calamares.desktop
```

If missing, create it:
```bash
mkdir -p ~/.config/autostart
cat > ~/.config/autostart/calamares.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Install NubiferOS
Comment=System Installer
Exec=pkexec calamares
Icon=calamares
Terminal=false
Categories=System;
X-GNOME-Autostart-enabled=true
EOF
```

**Check 2: Verify Calamares is installed**
```bash
which calamares
calamares --version
```

**Check 3: Check GNOME autostart settings**
```bash
# List all autostart applications
ls -la /etc/xdg/autostart/
ls -la ~/.config/autostart/

# Check if autostart is disabled in GNOME
gsettings get org.gnome.desktop.session autostart-enabled
```

**Check 4: Check system logs**
```bash
# Check for Calamares errors
journalctl -b | grep -i calamares

# Check GDM logs
journalctl -u gdm3
```

### Calamares Crashes on Launch

**Check configuration files:**
```bash
# Verify settings.conf syntax
cat /etc/calamares/settings.conf

# Check module configurations
ls -la /etc/calamares/modules/

# Verify branding
ls -la /etc/calamares/branding/nubiferos/
```

**Run with debug output:**
```bash
calamares -d
```

### Permission Issues

Calamares requires root privileges. If you see permission errors:

```bash
# Use pkexec (preferred)
pkexec calamares

# Or sudo
sudo calamares
```

### Missing Dependencies

If Calamares won't start due to missing libraries:

```bash
# Check for missing dependencies
ldd $(which calamares)

# Reinstall Calamares
sudo apt-get install --reinstall calamares calamares-settings-debian
```

## Configuration Files

### Main Configuration
- `/etc/calamares/settings.conf` - Main Calamares configuration
- `/etc/calamares/modules/*.conf` - Module-specific configurations

### Branding
- `/etc/calamares/branding/nubiferos/` - NubiferOS branding files

### Autostart
- `/etc/skel/.config/autostart/calamares.desktop` - Template for new users
- `~/.config/autostart/calamares.desktop` - User-specific autostart

## Verifying Installation Process

### Pre-Installation Checks

Before running the installer, verify:

1. **Network connectivity** (if installing cloud tools)
```bash
ping -c 3 google.com
```

2. **Disk space**
```bash
df -h
lsblk
```

3. **System requirements**
```bash
free -h  # At least 2GB RAM recommended
```

### During Installation

Monitor the installation process:

```bash
# In another terminal, watch logs
tail -f ~/.cache/Calamares/session.log

# Or system journal
journalctl -f | grep -i calamares
```

### Post-Installation

After installation completes:

1. **Don't reboot immediately** - verify the installation
2. **Check installed system**
```bash
# Mount the installed system
sudo mount /dev/sdXY /mnt
ls -la /mnt/boot/  # Verify kernel is installed
ls -la /mnt/etc/   # Verify system files
sudo umount /mnt
```

3. **Verify bootloader**
```bash
# Check if GRUB was installed
sudo fdisk -l  # Look for boot flag
```

## Common Issues and Solutions

### Issue: "Multiple users at login screen"

**Solution:** You may see both "live" and "installer" users at the login screen. Both should work, but use "live":
- Username: `live`
- Password: See `docs/guides/LIVE_USER_EXPLANATION.md`

The "installer" user may be created automatically by the live-boot system. The boot parameters now explicitly set `username=live` to ensure the correct user is used.

### Issue: Calamares window is blank/white

**Solution:** This is usually a QML/Qt issue:
```bash
# Check QML modules
dpkg -l | grep qml-module

# Reinstall QML dependencies
sudo apt-get install --reinstall \
    qml-module-qtquick2 \
    qml-module-qtquick-controls \
    qml-module-qtquick-layouts \
    qml-module-qtquick-window2
```

### Issue: Installation fails at bootloader step

**Solution:** Check the bootloader configuration:
```bash
cat /etc/calamares/modules/bootloader.conf
```

Verify the target disk is correct and has enough space.

### Issue: Installed system won't boot

**Solution:** See `docs/BOOT_TROUBLESHOOTING.md` and `docs/POST_INSTALL_BOOT_FIX.md`

## Rebuilding with Fixes

After making changes to the installer configuration:

```bash
# Rebuild the ISO
sudo ./build-nubiferos.sh

# Or rebuild just the installer
sudo ./build/install-calamares.sh
```

## Testing in Different Environments

### VirtualBox
```bash
# Create VM and test
./testing/create-virtualbox-vm.sh
```

### QEMU
```bash
qemu-system-x86_64 \
    -cdrom output/nubiferos-*.iso \
    -m 4096 \
    -enable-kvm \
    -boot d
```

### AWS (with NICE DCV)
```bash
# See aws-testing/README.md for full instructions
cd aws-testing
terraform apply
```

## Debugging Tips

### Enable Verbose Logging

Edit `/etc/calamares/settings.conf`:
```yaml
# Add or modify:
debug: true
```

### Check Module Execution

Calamares executes modules in sequence. Check which module is failing:
```bash
tail -f ~/.cache/Calamares/session.log
```

### Test Individual Modules

Some modules can be tested independently:
```bash
# Test the packages module
sudo calamares -d -D8 -T packages
```

## Additional Resources

- [Calamares Documentation](https://github.com/calamares/calamares/wiki)
- [Debian Calamares Guide](https://wiki.debian.org/Calamares)
- NubiferOS specific docs:
  - `INSTALLER_QUICKSTART.md`
  - `BUILD_CHECKLIST.md`
  - `docs/POST_INSTALL_BOOT_FIX.md`
