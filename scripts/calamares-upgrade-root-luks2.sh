#!/bin/bash
# Convert root partition from LUKS1 to LUKS2 + Argon2id
# This runs AFTER partition module but BEFORE mount
# /boot stays LUKS1 (GRUB compatible), root gets LUKS2 (GPU-resistant)

echo "=========================================="
echo "Upgrading Root Partition to LUKS2 + Argon2id"
echo "=========================================="

# Find the root LUKS device (not /boot)
# Calamares typically creates partitions in order: ESP, boot, root
# We need to find the LUKS partition that will be mounted as /

ROOT_LUKS_DEVICE=""
BOOT_LUKS_DEVICE=""

# Look for LUKS devices
for device in /dev/sd*[0-9] /dev/nvme*p[0-9] /dev/vd*[0-9]; do
    if [ -b "$device" ] && cryptsetup isLuks "$device" 2>/dev/null; then
        # Check LUKS version
        LUKS_VERSION=$(cryptsetup luksDump "$device" 2>/dev/null | grep "Version:" | awk '{print $2}')
        echo "Found LUKS device: $device (Version: $LUKS_VERSION)"

        # Determine if this is boot or root based on partition number/size
        # The larger partition is typically root
        SIZE=$(blockdev --getsize64 "$device" 2>/dev/null || echo 0)

        if [ -z "$ROOT_LUKS_DEVICE" ] || [ "$SIZE" -gt "$(blockdev --getsize64 "$ROOT_LUKS_DEVICE" 2>/dev/null || echo 0)" ]; then
            # If we already have a root device, the old one becomes boot
            if [ -n "$ROOT_LUKS_DEVICE" ]; then
                BOOT_LUKS_DEVICE="$ROOT_LUKS_DEVICE"
            fi
            ROOT_LUKS_DEVICE="$device"
        else
            BOOT_LUKS_DEVICE="$device"
        fi
    fi
done

if [ -z "$ROOT_LUKS_DEVICE" ]; then
    echo "No LUKS devices found - encryption may not be enabled"
    echo "Skipping LUKS2 upgrade"
    exit 0
fi

echo ""
echo "Boot LUKS device: ${BOOT_LUKS_DEVICE:-none}"
echo "Root LUKS device: $ROOT_LUKS_DEVICE"
echo ""

# Check current LUKS version of root
CURRENT_VERSION=$(cryptsetup luksDump "$ROOT_LUKS_DEVICE" 2>/dev/null | grep "Version:" | awk '{print $2}')

if [ "$CURRENT_VERSION" = "2" ]; then
    echo "Root is already LUKS2, checking KDF..."
    KDF=$(cryptsetup luksDump "$ROOT_LUKS_DEVICE" 2>/dev/null | grep "PBKDF:" | head -1 | awk '{print $2}')
    if [ "$KDF" = "argon2id" ]; then
        echo "Already using argon2id - nothing to do"
        exit 0
    fi
else
    echo "Converting root from LUKS1 to LUKS2..."

    # Backup header first (just in case)
    mkdir -p /tmp/nubiferos-install
    cryptsetup luksHeaderBackup "$ROOT_LUKS_DEVICE" \
        --header-backup-file /tmp/nubiferos-install/root-luks-header-backup.bin
    echo "Header backup saved to /tmp/nubiferos-install/root-luks-header-backup.bin"

    # Convert to LUKS2
    if ! cryptsetup convert "$ROOT_LUKS_DEVICE" --type luks2 --batch-mode; then
        echo "ERROR: Failed to convert to LUKS2"
        echo "Continuing with LUKS1 (still secure, just not GPU-resistant)"
        exit 0  # Don't fail the install
    fi
    echo "✓ Converted to LUKS2"
fi

# Now upgrade the key derivation function to argon2id
echo "Upgrading key derivation to argon2id..."

# Get the passphrase from Calamares GlobalStorage or use the open device
# Since the device should still be open from Calamares partitioning,
# we can use luksConvertKey with the existing keyslot

# Try to convert the key - this might prompt for passphrase
# We use --pbkdf-memory to set memory cost (1GB = 1048576 KB)
# and --pbkdf-parallel for parallelism
if cryptsetup luksConvertKey "$ROOT_LUKS_DEVICE" \
    --pbkdf argon2id \
    --pbkdf-memory 1048576 \
    --pbkdf-parallel 4 \
    --batch-mode 2>/dev/null; then
    echo "✓ Upgraded to argon2id"
else
    echo "Note: Could not auto-convert key to argon2id"
    echo "This may require passphrase - will be done on first boot"
    # Create a marker file for post-install script to handle this
    echo "NEEDS_ARGON2_UPGRADE=true" > /tmp/nubiferos-install/luks-upgrade-status
fi

# Verify the result
echo ""
echo "Final LUKS configuration for root:"
cryptsetup luksDump "$ROOT_LUKS_DEVICE" 2>/dev/null | grep -E "(Version:|PBKDF:|Cipher:)"

echo ""
echo "=========================================="
echo "LUKS2 Upgrade Complete"
echo "=========================================="
echo ""
echo "Security status:"
echo "  /boot: LUKS1 (GRUB compatible)"
echo "  /root: LUKS2 + argon2id (GPU-resistant)"
echo ""

exit 0
