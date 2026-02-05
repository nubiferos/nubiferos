#!/bin/bash
# Post-install cleanup for NubiferOS
# Removes live/installer user, kiosk mode configs, and other temporary files

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

# Unmask getty services for tty2-6 (restore normal VT access)
for tty in tty2 tty3 tty4 tty5 tty6; do
    systemctl unmask getty@${tty}.service 2>/dev/null || true
done
echo "  Unmasked getty services for tty2-6"

# Unmask ctrl-alt-del.target
systemctl unmask ctrl-alt-del.target 2>/dev/null || true
echo "  Unmasked ctrl-alt-del.target"

# ==========================================
# Enable graphical desktop for installed system
# ==========================================
echo "Configuring graphical desktop..."

# Enable GDM3
systemctl enable gdm3.service 2>/dev/null || true
echo "  Enabled gdm3.service"

# Set graphical.target as default
systemctl set-default graphical.target 2>/dev/null || true
echo "  Set default target to graphical.target"

# ==========================================
# Remove installer user
# ==========================================
# Remove installer user if it exists
if id "installer" &>/dev/null; then
    echo "Removing installer user..."
    userdel -r installer 2>/dev/null || userdel installer 2>/dev/null || true
    rm -rf /home/installer 2>/dev/null || true
    echo "Installer user removed"
else
    echo "No installer user found (good)"
fi

# Remove live user if it exists
if id "live" &>/dev/null; then
    echo "Removing live user..."
    userdel -r live 2>/dev/null || userdel live 2>/dev/null || true
    rm -rf /home/live 2>/dev/null || true
    echo "Live user removed"
fi

# Remove installer-specific sudoers files
rm -f /etc/sudoers.d/installer 2>/dev/null || true
rm -f /etc/sudoers.d/live-user 2>/dev/null || true

# Remove Calamares autostart entries
rm -f /etc/xdg/autostart/calamares.desktop 2>/dev/null || true
rm -f /etc/skel/.config/autostart/calamares.desktop 2>/dev/null || true

# Remove live-boot specific files (not needed on installed system)
rm -f /etc/live/boot.conf 2>/dev/null || true
rm -rf /etc/live 2>/dev/null || true

# Remove Calamares configuration (not needed on installed system)
# This prevents the first-boot wizard from thinking it's still in live mode
rm -rf /etc/calamares 2>/dev/null || true
echo "Removed /etc/calamares"

# Remove installer desktop shortcut from skel
rm -f /etc/skel/Desktop/Install*.desktop 2>/dev/null || true

# Clean up any temporary installer files
rm -f /tmp/nubiferos-* 2>/dev/null || true
rm -f /tmp/calamares-* 2>/dev/null || true

# Remove GDM auto-login config (installed system should require login)
if [ -f /etc/gdm3/daemon.conf ]; then
    echo "Removing auto-login configuration..."
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

# Same for custom.conf
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
