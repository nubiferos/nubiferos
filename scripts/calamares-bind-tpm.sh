#!/bin/bash
# Bind LUKS2 volume to TPM 2.0 via clevis for auto-unlock
#
# Runs during Calamares exec phase (dontChroot: true).
# Only acts if TPM marker exists from calamares-detect-tpm.sh.
# All failures are non-fatal — passphrase in keyslot 0 always works.

set -e

MARKER="/tmp/nubiferos-tpm-detected"

echo "=========================================="
echo "NubiferOS TPM Binding"
echo "=========================================="

# Check for TPM marker
if [ ! -f "$MARKER" ]; then
    echo "No TPM marker found — skipping TPM binding"
    echo "System will use passphrase-only unlock (LUKS1)"
    exit 0
fi

echo "TPM marker found — proceeding with TPM binding"
source "$MARKER"

# Find Calamares target root mount
# Calamares mounts the target at /tmp/calamares-root-* or similar
TARGET_ROOT=""
for mount_point in /tmp/calamares-root-*; do
    if [ -d "$mount_point/etc" ]; then
        TARGET_ROOT="$mount_point"
        break
    fi
done

# Fallback: check standard Calamares mount point
if [ -z "$TARGET_ROOT" ] && [ -d "/tmp/nubiferos/etc" ]; then
    TARGET_ROOT="/tmp/nubiferos"
fi

# Another fallback: search /proc/mounts for the target root
if [ -z "$TARGET_ROOT" ]; then
    TARGET_ROOT=$(awk '$2 ~ /^\/tmp\/(calamares|nubiferos)/ && $2 !~ /boot/ { print $2; exit }' /proc/mounts)
fi

if [ -z "$TARGET_ROOT" ] || [ ! -d "$TARGET_ROOT/etc" ]; then
    echo "ERROR: Cannot find Calamares target root mount"
    echo "TPM binding skipped — passphrase fallback will work"
    exit 0
fi
echo "✓ Target root: $TARGET_ROOT"

# Find the LUKS2 device (largest LUKS2 partition)
LUKS_DEVICE=""
for dev in /dev/sd?? /dev/vd?? /dev/nvme?n?p?; do
    [ -b "$dev" ] || continue
    if cryptsetup isLuks "$dev" 2>/dev/null; then
        LUKS_VER=$(cryptsetup luksDump "$dev" 2>/dev/null | grep "^Version:" | awk '{print $2}')
        if [ "$LUKS_VER" = "2" ]; then
            LUKS_DEVICE="$dev"
            echo "✓ Found LUKS2 device: $LUKS_DEVICE"
            break
        fi
    fi
done

if [ -z "$LUKS_DEVICE" ]; then
    echo "ERROR: No LUKS2 device found"
    echo "TPM binding skipped — passphrase fallback will work"
    exit 0
fi

# Find the open dm-crypt mapping for this device
DM_NAME=""
for dm in /dev/mapper/*; do
    [ -b "$dm" ] || continue
    [ "$dm" = "/dev/mapper/control" ] && continue
    BACKING=$(cryptsetup status "$dm" 2>/dev/null | grep "device:" | awk '{print $2}')
    if [ "$BACKING" = "$LUKS_DEVICE" ]; then
        DM_NAME=$(basename "$dm")
        echo "✓ Found dm-crypt mapping: $DM_NAME"
        break
    fi
done

if [ -z "$DM_NAME" ]; then
    echo "ERROR: No open dm-crypt mapping found for $LUKS_DEVICE"
    echo "TPM binding skipped — passphrase fallback will work"
    exit 0
fi

# Extract volume master key from open dm-crypt device
# This avoids needing the user's passphrase interactively
KEYFILE=$(mktemp /tmp/luks-vk-XXXXXX)
trap 'shred -u "$KEYFILE" 2>/dev/null; rm -f "$KEYFILE" 2>/dev/null' EXIT

echo "Extracting volume key from open mapping..."
VOLUME_KEY_HEX=$(dmsetup table --showkeys "$DM_NAME" 2>/dev/null | awk '{print $5}')
if [ -z "$VOLUME_KEY_HEX" ]; then
    echo "ERROR: Could not extract volume key via dmsetup"
    echo "TPM binding skipped — passphrase fallback will work"
    exit 0
fi

# Convert hex key to binary
echo -n "$VOLUME_KEY_HEX" | xxd -r -p > "$KEYFILE"
echo "✓ Volume key extracted"

# Bind LUKS2 device to TPM 2.0 via clevis
# PCR 7 = Secure Boot policy (protects against Evil Maid attacks)
echo "Binding LUKS2 to TPM 2.0 (PCR bank: sha256, PCR IDs: 7)..."
if clevis luks bind -f -d "$LUKS_DEVICE" -k "$KEYFILE" tpm2 '{"pcr_bank":"sha256","pcr_ids":"7"}' 2>&1; then
    echo "✓ LUKS2 bound to TPM 2.0"
else
    echo "ERROR: clevis luks bind failed"
    echo "TPM binding skipped — passphrase fallback will work"
    # Shred key and exit cleanly
    shred -u "$KEYFILE" 2>/dev/null || true
    exit 0
fi

# Shred the volume key immediately
shred -u "$KEYFILE" 2>/dev/null || true

# Update initramfs in target to include clevis hooks
echo "Updating initramfs with clevis hooks..."
if chroot "$TARGET_ROOT" update-initramfs -u -k all 2>&1; then
    echo "✓ initramfs updated with clevis-initramfs hooks"
else
    echo "WARNING: update-initramfs failed — TPM unlock may not work on first boot"
    echo "Passphrase fallback will still work"
fi

# Verify clevis hooks are in initramfs
echo "Verifying clevis in initramfs..."
INITRD=$(ls "$TARGET_ROOT"/boot/initrd.img-* 2>/dev/null | head -1)
if [ -n "$INITRD" ] && lsinitramfs "$INITRD" 2>/dev/null | grep -q clevis; then
    echo "✓ clevis hooks found in initramfs"
else
    echo "WARNING: clevis hooks not found in initramfs"
fi

# Create marker in target for prepare-bootloader
echo "TPM_ACTIVE=true" > "$TARGET_ROOT/etc/nubiferos-tpm-active"
echo "✓ Created /etc/nubiferos-tpm-active in target"

# Verify the binding
echo ""
echo "Verifying TPM binding..."
clevis luks list -d "$LUKS_DEVICE" 2>&1 || echo "WARNING: Could not list clevis bindings"

echo ""
echo "=========================================="
echo "TPM binding complete"
echo "  Device: $LUKS_DEVICE"
echo "  PCR: sha256:7"
echo "  Auto-unlock: enabled"
echo "  Passphrase fallback: keyslot 0"
echo "=========================================="

exit 0
