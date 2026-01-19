#!/bin/bash
# Quick test script to build a minimal bootable ISO for testing GRUB configuration
# This skips the full system build and just tests the bootloader

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEST_DIR="${SCRIPT_DIR}/grub-test"
ISO_DIR="${TEST_DIR}/iso"
OUTPUT_ISO="${TEST_DIR}/grub-test.iso"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[TEST]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*"
    exit 1
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

# Check dependencies
log "Checking dependencies..."
for cmd in grub-mkstandalone xorriso; do
    if ! command -v $cmd &> /dev/null; then
        error "Missing dependency: $cmd"
    fi
done

# Clean up old test
log "Cleaning up old test files..."
rm -rf "${TEST_DIR}"
mkdir -p "${ISO_DIR}/boot/grub"
mkdir -p "${ISO_DIR}/EFI/boot"
mkdir -p "${ISO_DIR}/live"

# Create a dummy kernel and initrd for testing
log "Creating dummy kernel and initrd..."
echo "DUMMY KERNEL - This is just for testing GRUB boot" > "${ISO_DIR}/boot/vmlinuz"
echo "DUMMY INITRD - This is just for testing GRUB boot" > "${ISO_DIR}/boot/initrd.img"

# Create a dummy squashfs (empty, just for structure)
log "Creating dummy filesystem..."
mkdir -p "${TEST_DIR}/dummy_root"
echo "Test system" > "${TEST_DIR}/dummy_root/test.txt"
mksquashfs "${TEST_DIR}/dummy_root" "${ISO_DIR}/live/filesystem.squashfs" -noappend -comp xz

# Create GRUB configuration
log "Creating GRUB configuration..."
cat > "${ISO_DIR}/boot/grub/grub.cfg" << 'EOF'
# Test GRUB configuration
set timeout=3
set default=0

insmod all_video
insmod gfxterm
terminal_output gfxterm

menuentry "GRUB Boot Test - Success!" {
    echo "=========================================="
    echo "SUCCESS: GRUB loaded correctly!"
    echo "=========================================="
    echo ""
    echo "Kernel: /boot/vmlinuz"
    echo "Initrd: /boot/initrd.img"
    echo ""
    echo "If you see this message, the GRUB bootloader"
    echo "is working correctly and can find its config."
    echo ""
    echo "Press any key to attempt kernel load..."
    read
    linux /boot/vmlinuz boot=live components quiet splash
    initrd /boot/initrd.img
}

menuentry "Test - List Devices" {
    echo "Available devices:"
    ls
    echo ""
    echo "Press any key to continue..."
    read
}
EOF

# Copy GRUB config to EFI location
cp "${ISO_DIR}/boot/grub/grub.cfg" "${ISO_DIR}/EFI/boot/grub.cfg"

# Create BIOS embedded config
log "Creating BIOS embedded config..."
cat > "${ISO_DIR}/boot/grub/embedded.cfg" << 'EOF'
# Try to load grub.cfg from common CD device names
set root=(cd)
configfile (cd)/boot/grub/grub.cfg
set root=(cd0)
configfile (cd0)/boot/grub/grub.cfg
set root=(cd1)
configfile (cd1)/boot/grub/grub.cfg
echo "Error: Could not find grub.cfg on any CD device"
echo "Available devices:"
ls
EOF

# Create UEFI embedded config
log "Creating UEFI embedded config..."
cat > "${ISO_DIR}/EFI/boot/embedded.cfg" << 'EOF'
# Search for the ISO filesystem and load grub.cfg
search --no-floppy --set=root --file /boot/grub/grub.cfg
if [ -s ($root)/boot/grub/grub.cfg ]; then
    configfile ($root)/boot/grub/grub.cfg
fi

# Fallback: try common device names
set root=(cd)
if [ -s (cd)/boot/grub/grub.cfg ]; then
    configfile (cd)/boot/grub/grub.cfg
fi

set root=(cd0)
if [ -s (cd0)/boot/grub/grub.cfg ]; then
    configfile (cd0)/boot/grub/grub.cfg
fi

# If we get here, none worked
echo "Error: Could not find grub.cfg"
echo "Tried: search, (cd), (cd0)"
echo "Root is set to: $root"
EOF

# Create GRUB BIOS image
log "Creating GRUB BIOS boot image..."
cd "${ISO_DIR}"
grub-mkstandalone \
    --format=i386-pc \
    --output="boot/grub/core.img" \
    --install-modules="linux normal iso9660 biosdisk memdisk search search_fs_file search_fs_uuid tar ls all_video gfxterm configfile part_msdos part_gpt" \
    --modules="linux normal iso9660 biosdisk memdisk search search_fs_file configfile part_msdos part_gpt" \
    --locales="" \
    --fonts="" \
    "boot/grub/grub.cfg=boot/grub/embedded.cfg"
cd - > /dev/null

cat /usr/lib/grub/i386-pc/cdboot.img "${ISO_DIR}/boot/grub/core.img" > "${ISO_DIR}/boot/grub/bios.img"

# Create GRUB EFI image
log "Creating GRUB EFI boot image..."
grub-mkstandalone \
    --format=x86_64-efi \
    --output="${ISO_DIR}/EFI/boot/BOOTX64.EFI" \
    --install-modules="linux normal iso9660 efi_gop efi_uga search search_fs_file search_fs_uuid tar ls all_video gfxterm configfile part_msdos part_gpt" \
    --modules="linux normal iso9660 efi_gop efi_uga search search_fs_file configfile part_msdos part_gpt" \
    --locales="" \
    --fonts="" \
    "boot/grub/grub.cfg=${ISO_DIR}/EFI/boot/embedded.cfg"

# Create EFI boot image
log "Creating EFI boot image..."
dd if=/dev/zero of="${ISO_DIR}/boot/grub/efi.img" bs=1M count=10 2>/dev/null
mkfs.vfat "${ISO_DIR}/boot/grub/efi.img" > /dev/null 2>&1

EFI_MOUNT="${TEST_DIR}/efi_mount"
mkdir -p "${EFI_MOUNT}"
sudo mount -o loop "${ISO_DIR}/boot/grub/efi.img" "${EFI_MOUNT}"
sudo mkdir -p "${EFI_MOUNT}/EFI/BOOT"
sudo cp "${ISO_DIR}/EFI/boot/BOOTX64.EFI" "${EFI_MOUNT}/EFI/BOOT/"
sudo cp "${ISO_DIR}/boot/grub/grub.cfg" "${EFI_MOUNT}/EFI/BOOT/"
sudo umount "${EFI_MOUNT}"
rmdir "${EFI_MOUNT}"

# Create ISO
log "Creating test ISO..."
xorriso -as mkisofs \
    -iso-level 3 \
    -full-iso9660-filenames \
    -volid "GRUB-TEST" \
    -output "${OUTPUT_ISO}" \
    -eltorito-boot boot/grub/bios.img \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    --eltorito-catalog boot/boot.cat \
    --grub2-boot-info \
    --grub2-mbr /usr/lib/grub/i386-pc/boot_hybrid.img \
    -eltorito-alt-boot \
    -e boot/grub/efi.img \
    -no-emul-boot \
    -append_partition 2 0xef "${ISO_DIR}/boot/grub/efi.img" \
    -partition_offset 16 \
    "${ISO_DIR}" 2>&1 | grep -v "^xorriso"

log "Test ISO created: ${OUTPUT_ISO}"
log "Size: $(du -h ${OUTPUT_ISO} | cut -f1)"

echo ""
echo "=========================================="
echo "Test ISO ready!"
echo "=========================================="
echo ""
echo "Location: ${OUTPUT_ISO}"
echo ""
echo "To test:"
echo "  1. QEMU (UEFI): qemu-system-x86_64 -bios /usr/share/ovmf/OVMF.fd -cdrom ${OUTPUT_ISO} -m 512"
echo "  2. QEMU (BIOS): qemu-system-x86_64 -cdrom ${OUTPUT_ISO} -m 512"
echo "  3. VirtualBox: Create VM and attach ${OUTPUT_ISO}"
echo ""
echo "Expected result:"
echo "  - Boot menu appears with 'GRUB Boot Test - Success!' option"
echo "  - Selecting it shows success message"
echo "  - If you see 'error: file /boot/vmlinuz not found', GRUB config is broken"
echo ""
