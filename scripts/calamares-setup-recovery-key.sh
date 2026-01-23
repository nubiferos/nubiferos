#!/bin/bash
# Generate and add LUKS recovery key during installation
# This runs after partition module, in the live environment (not chroot)

echo "=========================================="
echo "Setting up LUKS Recovery Key"
echo "=========================================="

# Find the LUKS device - look for the root partition's backing device
# The partition module stores info in /tmp/calamares-* files, but we can also
# detect LUKS devices directly

LUKS_DEVICE=""

# Method 1: Look for active LUKS devices
for device in /dev/sd* /dev/nvme* /dev/vd*; do
    if [ -b "$device" ] && cryptsetup isLuks "$device" 2>/dev/null; then
        LUKS_DEVICE="$device"
        echo "Found LUKS device: $LUKS_DEVICE"
        break
    fi
done

# Method 2: Check partitions if no base device found
if [ -z "$LUKS_DEVICE" ]; then
    for device in /dev/sd*[0-9] /dev/nvme*p[0-9] /dev/vd*[0-9]; do
        if [ -b "$device" ] && cryptsetup isLuks "$device" 2>/dev/null; then
            LUKS_DEVICE="$device"
            echo "Found LUKS partition: $LUKS_DEVICE"
            break
        fi
    done
fi

if [ -z "$LUKS_DEVICE" ]; then
    echo "No LUKS device found - encryption may not be enabled"
    echo "Skipping recovery key setup"
    exit 0
fi

echo "LUKS device: $LUKS_DEVICE"

# Generate a recovery key (5 groups of 5 characters, like xxxxx-xxxxx-xxxxx-xxxxx-xxxxx)
RECOVERY_KEY=$(cat /dev/urandom | tr -dc 'A-Z0-9' | fold -w 5 | head -n 5 | paste -sd '-')

echo "Generated recovery key"

# We need the original passphrase to add a new key
# The passphrase is stored in Calamares GlobalStorage, but accessing it from
# shell is tricky. Instead, we'll use a keyfile approach.

# Check if we can find the passphrase from the Calamares environment
# Calamares stores it in memory, but we can access via the open LUKS container

# Alternative approach: Create the recovery key file and add it via keyfile
RECOVERY_KEYFILE="/tmp/nubiferos-recovery-key"
echo -n "$RECOVERY_KEY" > "$RECOVERY_KEYFILE"
chmod 600 "$RECOVERY_KEYFILE"

# The LUKS device should already be open from the partition module
# We need to add the key using the existing unlocked state
# This requires the original passphrase OR we need to use a different approach

# For now, let's save the recovery key info and handle it differently:
# We'll add the recovery key during the chroot phase using the keyfile that
# Calamares's luksbootkeyfile module creates

# Save recovery key for later use and for user display
mkdir -p /tmp/nubiferos-install
echo "$RECOVERY_KEY" > /tmp/nubiferos-install/recovery-key.txt
chmod 600 /tmp/nubiferos-install/recovery-key.txt

# Also create a formatted version for the user
cat > /tmp/nubiferos-install/RECOVERY_KEY_INFO.txt << EOF
╔══════════════════════════════════════════════════════════════════╗
║                  NubiferOS RECOVERY KEY                          ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  Your disk encryption recovery key is:                           ║
║                                                                  ║
║      $RECOVERY_KEY
║                                                                  ║
║  IMPORTANT:                                                      ║
║  • Write this key down and store it in a safe place             ║
║  • This key can unlock your disk if you forget your password    ║
║  • Anyone with this key can access your data                    ║
║  • Delete this file after saving the key securely               ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
EOF

echo "Recovery key saved to /tmp/nubiferos-install/"
echo "Will be copied to user's desktop during post-install"

exit 0
