#!/bin/bash
# Copy recovery key to user's desktop (runs in chroot)
# This runs after users module creates the user

echo "=========================================="
echo "Copying Recovery Key to Desktop"
echo "=========================================="

RECOVERY_KEY_FILE="/tmp/nubiferos-install/RECOVERY_KEY_INFO.txt"
RECOVERY_KEY_RAW="/tmp/nubiferos-install/recovery-key.txt"

# Check if recovery key was generated (only if LUKS is enabled)
if [ ! -f "$RECOVERY_KEY_FILE" ]; then
    echo "No recovery key found - encryption may not be enabled"
    exit 0
fi

# Find the user created during installation (not root, not system users)
# Look in /home for directories
INSTALL_USER=""
for userdir in /home/*/; do
    username=$(basename "$userdir")
    # Skip installer and live users
    if [ "$username" != "installer" ] && [ "$username" != "live" ] && [ -d "$userdir" ]; then
        INSTALL_USER="$username"
        break
    fi
done

if [ -z "$INSTALL_USER" ]; then
    echo "WARNING: Could not find installed user, saving to /root instead"
    mkdir -p /root/Desktop
    cp "$RECOVERY_KEY_FILE" /root/Desktop/
    chmod 600 /root/Desktop/RECOVERY_KEY_INFO.txt
    exit 0
fi

echo "Found user: $INSTALL_USER"

# Create Desktop directory if it doesn't exist
USER_HOME="/home/$INSTALL_USER"
mkdir -p "$USER_HOME/Desktop"

# Copy recovery key info
cp "$RECOVERY_KEY_FILE" "$USER_HOME/Desktop/"
chmod 600 "$USER_HOME/Desktop/RECOVERY_KEY_INFO.txt"

# Set ownership
chown -R "$INSTALL_USER:$INSTALL_USER" "$USER_HOME/Desktop"

# Also create a script to add the recovery key to LUKS
cat > "$USER_HOME/Desktop/add-recovery-key.sh" << 'EOF'
#!/bin/bash
# Add the recovery key as a second LUKS key slot
# This allows you to unlock your disk with either your passphrase OR the recovery key

echo "NubiferOS Recovery Key Setup"
echo "============================"
echo ""
echo "This will add your recovery key as a second unlock method for your encrypted disk."
echo "You'll need to enter your current disk encryption passphrase."
echo ""

# Read recovery key from file
RECOVERY_KEY=$(cat ~/Desktop/RECOVERY_KEY_INFO.txt | grep -A1 "recovery key is:" | tail -1 | tr -d ' ')

if [ -z "$RECOVERY_KEY" ]; then
    echo "ERROR: Could not read recovery key from file"
    exit 1
fi

# Find LUKS device
LUKS_DEVICE=$(lsblk -o NAME,FSTYPE -r | grep crypto_LUKS | head -1 | cut -d' ' -f1)
if [ -z "$LUKS_DEVICE" ]; then
    # Try to find from crypttab
    LUKS_DEVICE=$(cat /etc/crypttab | grep -v '^#' | head -1 | awk '{print $2}')
fi

if [ -z "$LUKS_DEVICE" ]; then
    echo "ERROR: Could not find LUKS device"
    exit 1
fi

# Make sure it's a full path
if [[ ! "$LUKS_DEVICE" == /dev/* ]]; then
    LUKS_DEVICE="/dev/$LUKS_DEVICE"
fi

echo "LUKS device: $LUKS_DEVICE"
echo ""
echo "Enter your current disk encryption passphrase:"

# Add recovery key
echo -n "$RECOVERY_KEY" | sudo cryptsetup luksAddKey "$LUKS_DEVICE" -

if [ $? -eq 0 ]; then
    echo ""
    echo "SUCCESS! Recovery key has been added."
    echo ""
    echo "You can now unlock your disk with either:"
    echo "  1. Your regular passphrase"
    echo "  2. The recovery key: $RECOVERY_KEY"
    echo ""
    echo "IMPORTANT: Save the recovery key somewhere safe, then delete these files:"
    echo "  rm ~/Desktop/RECOVERY_KEY_INFO.txt"
    echo "  rm ~/Desktop/add-recovery-key.sh"
else
    echo ""
    echo "FAILED to add recovery key. Please try again."
fi
EOF

chmod +x "$USER_HOME/Desktop/add-recovery-key.sh"
chown "$INSTALL_USER:$INSTALL_USER" "$USER_HOME/Desktop/add-recovery-key.sh"

echo "Recovery key info copied to $USER_HOME/Desktop/"
echo "User can run add-recovery-key.sh to add it to LUKS"

exit 0
