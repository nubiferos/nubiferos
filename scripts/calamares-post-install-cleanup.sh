#!/bin/bash
# Post-install cleanup for NubiferOS
# Removes installer/kiosk configs and prepares the installed system for normal use
#
# IMPORTANT: This runs inside a Calamares chroot (dontChroot: false).
# systemctl commands may not work reliably in a chroot, so we use
# direct symlink manipulation for critical operations.

echo "=========================================="
echo "NubiferOS Post-Install Cleanup"
echo "=========================================="

# ==========================================
# Remove kiosk mode configurations
# ==========================================
echo "Removing kiosk mode configurations..."

# Remove kiosk-specific getty autologin
rm -rf /etc/systemd/system/getty@tty1.service.d 2>/dev/null || true
echo "  Removed getty autologin override"

# Remove kiosk X11 lockdown config
rm -f /etc/X11/xorg.conf.d/10-no-vt-switch.conf 2>/dev/null || true
echo "  Removed X11 VT lockdown"

# Remove kiosk sysctl lockdown (re-enable SysRq for debugging)
rm -f /etc/sysctl.d/99-kiosk-lockdown.conf 2>/dev/null || true
echo "  Removed sysctl lockdown"

# Remove kiosk sudoers file
rm -f /etc/sudoers.d/installer-kiosk 2>/dev/null || true
echo "  Removed kiosk sudoers"

# Unmask getty services for tty2-6 (direct symlink removal - works in chroot)
for tty in tty2 tty3 tty4 tty5 tty6; do
    rm -f /etc/systemd/system/getty@${tty}.service 2>/dev/null || true
done
echo "  Unmasked getty services for tty2-6"

# Unmask ctrl-alt-del.target (remove the /dev/null symlink)
rm -f /etc/systemd/system/ctrl-alt-del.target 2>/dev/null || true
echo "  Unmasked ctrl-alt-del.target"

# ==========================================
# Enable graphical desktop for installed system
# (Direct symlink manipulation - reliable in chroot)
# ==========================================
echo "Configuring graphical desktop..."

# Enable GDM3 - create the symlink directly
# On Debian bookworm, gdm3 unit is at /lib/systemd/system/gdm.service
mkdir -p /etc/systemd/system/display-manager.service.d 2>/dev/null || true
if [ -f /lib/systemd/system/gdm.service ]; then
    ln -sf /lib/systemd/system/gdm.service /etc/systemd/system/display-manager.service
    echo "  Enabled gdm.service via display-manager.service symlink"
elif [ -f /lib/systemd/system/gdm3.service ]; then
    ln -sf /lib/systemd/system/gdm3.service /etc/systemd/system/display-manager.service
    echo "  Enabled gdm3.service via display-manager.service symlink"
else
    echo "  WARNING: Could not find gdm service file!"
    ls /lib/systemd/system/gdm* 2>/dev/null || echo "  No gdm* files found in /lib/systemd/system/"
fi

# Set graphical.target as default (direct symlink - works in chroot)
ln -sf /lib/systemd/system/graphical.target /etc/systemd/system/default.target
echo "  Set default target to graphical.target"

# NOTE: Do NOT use systemctl here - even in a chroot, it can talk to the
# live system's systemd via D-Bus and kill the running X session.
# The direct symlinks above are sufficient.

# ==========================================
# Remove installer user
# ==========================================
if id "installer" &>/dev/null; then
    echo "Removing installer user..."
    # NOTE: Do NOT pkill here - /proc is bind-mounted from the live system
    # and pkill would kill the running Calamares/X session
    userdel -r installer 2>/dev/null || userdel installer 2>/dev/null || true
    rm -rf /home/installer 2>/dev/null || true
    echo "  Installer user removed"
else
    echo "  No installer user found (good)"
fi

# Remove live user if it exists
if id "live" &>/dev/null; then
    echo "Removing live user..."
    userdel -r live 2>/dev/null || userdel live 2>/dev/null || true
    rm -rf /home/live 2>/dev/null || true
    echo "  Live user removed"
fi

# ==========================================
# Remove installer artifacts
# ==========================================
echo "Removing installer artifacts..."

# Remove installer-specific sudoers files (all variants)
rm -f /etc/sudoers.d/installer 2>/dev/null || true
rm -f /etc/sudoers.d/installer-restricted 2>/dev/null || true
rm -f /etc/sudoers.d/installer-kiosk 2>/dev/null || true
rm -f /etc/sudoers.d/live-user 2>/dev/null || true

# Remove Calamares autostart entries
rm -f /etc/xdg/autostart/calamares.desktop 2>/dev/null || true
rm -f /etc/skel/.config/autostart/calamares.desktop 2>/dev/null || true

# Remove Calamares autostart service
rm -f /etc/systemd/system/calamares-autostart.service 2>/dev/null || true

# Remove Calamares helper scripts
rm -f /usr/local/bin/calamares-exit-handler 2>/dev/null || true
rm -f /usr/local/bin/install-nubiferos 2>/dev/null || true

# Remove boot-test marker service (live-ISO CI instrumentation; inert on
# installed systems via its boot=live guard, but no reason to ship it)
rm -f /etc/systemd/system/multi-user.target.wants/nubifer-boot-test.service 2>/dev/null || true
rm -f /usr/lib/systemd/system/nubifer-boot-test.service 2>/dev/null || true
rm -f /usr/local/bin/nubifer-boot-test.sh 2>/dev/null || true

# Remove live-boot specific files (not needed on installed system)
rm -f /etc/live/boot.conf 2>/dev/null || true
rm -rf /etc/live 2>/dev/null || true

# Remove Calamares configuration (prevents first-boot wizard from thinking it's in live mode)
rm -rf /etc/calamares 2>/dev/null || true
echo "  Removed /etc/calamares"

# Remove installer desktop shortcut from skel
rm -f /etc/skel/Desktop/Install*.desktop 2>/dev/null || true

# Clean up any temporary installer files
rm -f /tmp/nubiferos-* 2>/dev/null || true
rm -f /tmp/calamares-* 2>/dev/null || true

# ==========================================
# Configure GDM for normal login (no auto-login)
# ==========================================
if [ -f /etc/gdm3/daemon.conf ]; then
    echo "Configuring GDM for normal login..."
    cat > /etc/gdm3/daemon.conf << 'EOF'
[daemon]
WaylandEnable=true
# Auto-login disabled for installed system

[security]

[xdmcp]

[chooser]

[debug]
EOF
fi

if [ -f /etc/gdm3/custom.conf ]; then
    cat > /etc/gdm3/custom.conf << 'EOF'
[daemon]
WaylandEnable=true

[security]

[xdmcp]

[chooser]

[debug]
EOF
fi

echo "=========================================="
echo "Post-install cleanup complete"
echo "=========================================="

# ==========================================
# Verification - log what we ended up with
# ==========================================
echo "Verification:"
echo "  default.target -> $(readlink -f /etc/systemd/system/default.target 2>/dev/null || echo 'NOT SET')"
echo "  display-manager -> $(readlink -f /etc/systemd/system/display-manager.service 2>/dev/null || echo 'NOT SET')"
echo "  installer user: $(id installer 2>/dev/null && echo 'STILL EXISTS (BAD)' || echo 'removed (good)')"
echo "  getty@tty1 override: $(ls /etc/systemd/system/getty@tty1.service.d/ 2>/dev/null && echo 'STILL EXISTS (BAD)' || echo 'removed (good)')"

# Enable CLI wrappers by default (Firejail isolation)
echo "Enabling CLI wrappers..."
if [ -d /usr/local/lib/nubifer/cli-wrappers ]; then
    ln -sf /usr/local/lib/nubifer/cli-wrappers/aws /usr/local/bin/aws
    ln -sf /usr/local/lib/nubifer/cli-wrappers/az /usr/local/bin/az
    ln -sf /usr/local/lib/nubifer/cli-wrappers/gcloud /usr/local/bin/gcloud
    ln -sf /usr/local/lib/nubifer/cli-wrappers/oci /usr/local/bin/oci
    echo "CLI wrappers enabled (aws, az, gcloud, oci)"
else
    echo "CLI wrappers directory not found, skipping"
fi

echo "=========================================="
echo "NubiferOS installation complete!"
echo "=========================================="

exit 0
