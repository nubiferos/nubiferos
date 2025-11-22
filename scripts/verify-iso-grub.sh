#!/bin/bash
# Script to verify GRUB modules in the ISO

set -e

ISO_FILE="${1:-output/nubiferos-*.iso}"

if [ ! -f $ISO_FILE ]; then
    echo "❌ ISO file not found: $ISO_FILE"
    echo "Usage: $0 [path-to-iso]"
    exit 1
fi

echo "=========================================="
echo "GRUB Module Verification"
echo "=========================================="
echo ""
echo "ISO: $ISO_FILE"
echo ""

# Mount the ISO
MOUNT_DIR=$(mktemp -d)
echo "Mounting ISO to $MOUNT_DIR..."
sudo mount -o loop "$ISO_FILE" "$MOUNT_DIR"

echo ""
echo "Checking GRUB files..."
echo ""

# Check if GRUB files exist
if [ -f "$MOUNT_DIR/boot/grub/bios.img" ]; then
    echo "✓ BIOS boot image found"
    BIOS_SIZE=$(stat -f%z "$MOUNT_DIR/boot/grub/bios.img" 2>/dev/null || stat -c%s "$MOUNT_DIR/boot/grub/bios.img")
    echo "  Size: $BIOS_SIZE bytes"
else
    echo "✗ BIOS boot image NOT found"
fi

if [ -f "$MOUNT_DIR/boot/grub/grub.cfg" ]; then
    echo "✓ GRUB config found"
    echo ""
    echo "  Content:"
    cat "$MOUNT_DIR/boot/grub/grub.cfg" | sed 's/^/    /'
else
    echo "✗ GRUB config NOT found"
fi

echo ""

if [ -f "$MOUNT_DIR/boot/grub/embedded.cfg" ]; then
    echo "✓ Embedded config found"
    echo ""
    echo "  Content:"
    cat "$MOUNT_DIR/boot/grub/embedded.cfg" | sed 's/^/    /'
else
    echo "✗ Embedded config NOT found"
fi

echo ""

# Check kernel and initrd
if [ -f "$MOUNT_DIR/boot/vmlinuz" ]; then
    echo "✓ Kernel found"
    KERNEL_SIZE=$(stat -f%z "$MOUNT_DIR/boot/vmlinuz" 2>/dev/null || stat -c%s "$MOUNT_DIR/boot/vmlinuz")
    echo "  Size: $((KERNEL_SIZE / 1024 / 1024)) MB"
else
    echo "✗ Kernel NOT found"
fi

if [ -f "$MOUNT_DIR/boot/initrd.img" ]; then
    echo "✓ Initrd found"
    INITRD_SIZE=$(stat -f%z "$MOUNT_DIR/boot/initrd.img" 2>/dev/null || stat -c%s "$MOUNT_DIR/boot/initrd.img")
    echo "  Size: $((INITRD_SIZE / 1024 / 1024)) MB"
else
    echo "✗ Initrd NOT found"
fi

echo ""

# Try to extract and check modules from core.img
if [ -f "$MOUNT_DIR/boot/grub/core.img" ]; then
    echo "Checking GRUB modules in core.img..."
    echo ""
    
    # Copy core.img to temp location for analysis
    TEMP_CORE=$(mktemp)
    cp "$MOUNT_DIR/boot/grub/core.img" "$TEMP_CORE"
    
    # Use strings to find module names (they're embedded as strings)
    echo "Modules found in core.img:"
    strings "$TEMP_CORE" | grep -E '^(linux|normal|iso9660|biosdisk|search|configfile|all_video|gfxterm)$' | sort -u | sed 's/^/  ✓ /'
    
    # Check for search variants
    if strings "$TEMP_CORE" | grep -q "search_fs_file"; then
        echo "  ✓ search_fs_file"
    else
        echo "  ✗ search_fs_file (MISSING - needed for 'search --file')"
    fi
    
    if strings "$TEMP_CORE" | grep -q "search_fs_uuid"; then
        echo "  ✓ search_fs_uuid"
    else
        echo "  ⚠ search_fs_uuid (optional)"
    fi
    
    rm "$TEMP_CORE"
fi

echo ""
echo "=========================================="
echo "Verification Complete"
echo "=========================================="

# Unmount
sudo umount "$MOUNT_DIR"
rmdir "$MOUNT_DIR"

echo ""
echo "If 'search_fs_file' is missing, the embedded.cfg won't work!"
echo "The search command needs this module to find files."
