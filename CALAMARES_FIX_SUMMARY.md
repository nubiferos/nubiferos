# Calamares Installer Autostart Fix

## Problem

The Calamares installer was installed but not launching automatically when booting into the live environment. Users had to manually find and launch it.

## Root Cause

The `install-calamares.sh` script was installing Calamares but not creating an autostart configuration file. Without this, GNOME doesn't know to launch the installer automatically.

## Solution

Updated `build/install-calamares.sh` to create an autostart desktop entry that:
1. Creates `/etc/skel/.config/autostart/calamares.desktop` (template for new users)
2. Copies it to `/home/live/.config/autostart/` (for the live user)
3. Sets proper permissions

The autostart file tells GNOME to automatically launch Calamares with elevated privileges (`pkexec`) when the user logs in.

## Testing

### In Your Current Live Environment

If you're already booted into the live environment and Calamares isn't showing:

**Quick test:**
```bash
./testing/quick-calamares-test.sh
```

**Manual launch:**
```bash
pkexec calamares
# or
sudo calamares
```

**Create autostart for current session:**
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

Then log out and log back in.

### After Rebuilding ISO

1. Rebuild the ISO with the fix:
```bash
sudo ./build-nubiferos.sh
```

2. Boot the new ISO

3. Calamares should launch automatically after login

4. If it doesn't, run the test script:
```bash
./testing/test-calamares.sh
```

## Files Changed

- `build/install-calamares.sh` - Added autostart configuration
- `testing/test-calamares.sh` - Comprehensive test script (new)
- `testing/quick-calamares-test.sh` - Quick manual test (new)
- `docs/CALAMARES_TESTING.md` - Full testing and troubleshooting guide (new)

## User Account Info

The live ISO uses:
- **Username:** `live`
- **Password:** `live`
- **Auto-login:** Enabled
- **Sudo access:** Yes

(Note: There is no "installer" user - only "live")

## Verification Checklist

After rebuilding and booting the new ISO:

- [ ] System boots to GNOME desktop automatically
- [ ] Logged in as "live" user
- [ ] Calamares installer window appears automatically
- [ ] Can proceed through installation steps
- [ ] Installation completes successfully
- [ ] Installed system boots properly

## Troubleshooting

If Calamares still doesn't autostart:

1. **Check if file exists:**
   ```bash
   ls -la ~/.config/autostart/calamares.desktop
   ```

2. **Check if Calamares is installed:**
   ```bash
   which calamares
   ```

3. **Check logs:**
   ```bash
   journalctl -b | grep -i calamares
   ```

4. **Launch manually to test:**
   ```bash
   pkexec calamares
   ```

See `docs/CALAMARES_TESTING.md` for comprehensive troubleshooting.

## Next Steps

1. Rebuild the ISO with the fix
2. Test in a VM or on hardware
3. Verify autostart works
4. If issues persist, check the detailed testing guide

## Related Documentation

- `docs/CALAMARES_TESTING.md` - Complete testing guide
- `INSTALLER_QUICKSTART.md` - Installer customization
- `BUILD_CHECKLIST.md` - Build process checklist
- `docs/POST_INSTALL_BOOT_FIX.md` - Post-installation boot issues
