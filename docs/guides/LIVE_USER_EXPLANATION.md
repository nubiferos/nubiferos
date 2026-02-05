# Live User Configuration Explained

## Why Multiple Users Appear

When you boot the NubiferOS live ISO, you may see multiple users at the login screen:

1. **live** - Explicitly created by our build scripts
2. **installer** - May be created by Debian's live-boot/live-config system

## How Live Users Are Created

### Our Explicit User Creation

In `build/install-desktop.sh`, we explicitly create the "live" user:

```bash
chroot_exec "useradd -m -s /bin/bash -c 'Live User' live"
chroot_exec "echo 'live:live' | chpasswd"
chroot_exec "usermod -aG sudo live"
```

This creates:
- Username: `live`
- Password: `live`
- Home: `/home/live`
- Sudo access: Yes

> **Note:** This user exists only during the installation process. It is automatically removed by the post-install cleanup after installation completes.

### Debian live-boot System

The `live-boot` package (installed for live CD functionality) may also create users based on:

1. **Boot parameters** - The kernel command line can specify username
2. **live-config** - Debian's live system configuration tool
3. **Default behavior** - If no username specified, may create "user" or "installer"

## Boot Parameters

Our GRUB configuration now explicitly sets the username:

```
linux /boot/vmlinuz boot=live components quiet splash username=live
```

The `username=live` parameter tells live-boot to use "live" as the username.

## Why You Might See "installer"

If you see an "installer" user, it could be because:

1. **live-config components** - The `components` boot parameter enables various live-config scripts
2. **Calamares integration** - Some live systems create an "installer" user for the installer
3. **Previous boot** - If you booted without the `username=live` parameter

## Which User Should You Use?

**Use the "live" user** - This is the intended user with:
- Known password (see above)
- Proper sudo access
- Autostart configuration for Calamares
- All NubiferOS customizations

The "installer" user (if it appears) should also work, but may have:
- Unknown or no password
- Different home directory setup
- May or may not have autostart configured

## Autostart Configuration

Both users should have Calamares autostart because:

1. **Template in /etc/skel** - New users get autostart from skeleton
2. **Explicit copy** - We copy to both `/home/live` and `/home/installer`

```bash
# From install-calamares.sh
mkdir -p "${CHROOT_DIR}/etc/skel/.config/autostart"
# Create calamares.desktop in skel

# Copy to live user
if [ -d "${CHROOT_DIR}/home/live" ]; then
    cp to /home/live/.config/autostart/
fi

# Copy to installer user if it exists
if [ -d "${CHROOT_DIR}/home/installer" ]; then
    cp to /home/installer/.config/autostart/
fi
```

## Verifying User Configuration

Run this script in the live environment to check users:

```bash
./testing/check-users.sh
```

This will show:
- All users with home directories
- Which users have login shells
- Current user and permissions
- Live-boot configuration

## Troubleshooting

### Can't log in as "live"

If the "live" user doesn't appear or won't accept the password:

1. **Check if user exists:**
   ```bash
   grep live /etc/passwd
   ```

2. **Check home directory:**
   ```bash
   ls -la /home/live
   ```

3. **Try the other user** (installer) if available

4. **Boot with explicit username:**
   Edit GRUB entry and add `username=live` to kernel parameters

### Autostart doesn't work for either user

1. **Check autostart file exists:**
   ```bash
   ls -la ~/.config/autostart/calamares.desktop
   ```

2. **Manually create it:**
   ```bash
   mkdir -p ~/.config/autostart
   cat > ~/.config/autostart/calamares.desktop << 'EOF'
   [Desktop Entry]
   Type=Application
   Name=Install NubiferOS
   Exec=pkexec calamares
   Icon=calamares
   Terminal=false
   X-GNOME-Autostart-enabled=true
   EOF
   ```

3. **Log out and back in**

### Want to disable auto-login

Edit `/etc/gdm3/custom.conf` and remove:
```
AutomaticLoginEnable=true
AutomaticLogin=live
```

Then restart GDM:
```bash
sudo systemctl restart gdm3
```

## For Production

Before releasing to production, consider:

1. **Remove auto-login** - Force users to see the installer user
2. **Set better username** - Maybe "installer" is more intuitive
3. **Remove test user** - The "live" user is marked as "TESTING ONLY"
4. **Lock down permissions** - Ensure installer user has minimal access

See `TODO_REMOVE_LIVE_CD.md` for the production checklist.

## Technical Details

### live-boot Package

The `live-boot` package provides:
- Initramfs scripts for booting from read-only media
- User creation based on boot parameters
- Automatic hardware detection
- Persistence support (if configured)

### live-config Package

The `live-config` package (if installed) provides:
- Additional system configuration
- User customization
- Locale setup
- Keyboard configuration

We use `live-boot` but may not need `live-config` depending on our needs.

### Boot Parameter Reference

Common live-boot parameters:
- `boot=live` - Enable live boot mode
- `username=NAME` - Set the live user name
- `hostname=NAME` - Set the hostname
- `components` - Enable live-config components
- `quiet` - Reduce boot messages
- `splash` - Show graphical boot splash
- `nomodeset` - Disable kernel mode setting (safe mode)

## Related Files

- `build/install-desktop.sh` - Creates the live user
- `build/install-calamares.sh` - Sets up autostart
- `build/build-iso.sh` - Configures boot parameters
- `testing/check-users.sh` - User verification script
- `docs/CALAMARES_TESTING.md` - Installer testing guide
