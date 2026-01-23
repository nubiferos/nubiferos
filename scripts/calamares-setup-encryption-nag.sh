#!/bin/bash
# Setup encryption nag if user installed without encryption
# This runs in chroot at the end of installation

echo "=========================================="
echo "Checking if disk encryption is enabled..."
echo "=========================================="

# Always install the nag script (it checks conditions before nagging)
if [ -f /usr/share/nubiferos/nubiferos-encryption-nag.sh ]; then
    cp /usr/share/nubiferos/nubiferos-encryption-nag.sh /usr/local/bin/
    chmod +x /usr/local/bin/nubiferos-encryption-nag.sh
fi

# Detect if root filesystem is encrypted by checking /etc/crypttab
# If crypttab exists and has entries, encryption is enabled
ENCRYPTION_ENABLED=false

if [ -f /etc/crypttab ]; then
    # Check if crypttab has actual entries (not just comments)
    if grep -v '^#' /etc/crypttab | grep -q '[a-z]'; then
        ENCRYPTION_ENABLED=true
        echo "Found entries in /etc/crypttab - encryption is enabled"
    fi
fi

# Also check if any LUKS devices are referenced in fstab
if [ -f /etc/fstab ]; then
    if grep -q '/dev/mapper/' /etc/fstab; then
        ENCRYPTION_ENABLED=true
        echo "Found LUKS mapper devices in /etc/fstab - encryption is enabled"
    fi
fi

echo "Encryption enabled: $ENCRYPTION_ENABLED"

# If encryption is NOT enabled, set up the eternal nag
if [ "$ENCRYPTION_ENABLED" = "false" ]; then
    echo "=========================================="
    echo "User bypassed encryption requirement"
    echo "Setting up eternal nag notifications..."
    echo "=========================================="

    # Install autostart for all users via /etc/xdg/autostart
    mkdir -p /etc/xdg/autostart
    cat > /etc/xdg/autostart/nubiferos-encryption-nag.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=NubiferOS Security Check
Comment=Reminds users about encryption status
Exec=/usr/local/bin/nubiferos-encryption-nag.sh
Icon=security-low
Terminal=false
Hidden=false
X-GNOME-Autostart-enabled=true
X-GNOME-Autostart-Delay=5
EOF

    # Create shame file for the user that will be created
    # This gets created in /etc/skel so all new users get it
    mkdir -p /etc/skel/.config/nubiferos
    echo "0" > /etc/skel/.config/nubiferos/.no-encryption-shame

    echo "Nag notifications configured. User will be reminded on every login."
else
    echo "Encryption enabled - no nag notifications needed."
fi

exit 0
