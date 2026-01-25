#!/bin/bash
# Post-install cleanup for NubiferOS
# Removes live/installer user and other temporary files

echo "=========================================="
echo "NubiferOS Post-Install Cleanup"
echo "=========================================="

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
