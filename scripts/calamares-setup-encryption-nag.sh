#!/bin/bash
# Setup encryption nag if user bypassed encryption requirement
# This runs in chroot at the end of installation

SHAME_FLAG="/tmp/nubiferos-install-no-encryption.log"

# Always install the nag script (it checks for shame file before nagging)
cp /usr/share/nubiferos/nubiferos-encryption-nag.sh /usr/local/bin/
chmod +x /usr/local/bin/nubiferos-encryption-nag.sh

# Check if user bypassed encryption
if [ -f "$SHAME_FLAG" ]; then
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
