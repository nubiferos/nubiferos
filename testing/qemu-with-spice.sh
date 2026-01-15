#!/bin/bash
# Launch QEMU with SPICE support for clipboard sharing and better graphics

set -e

# Find the ISO file
ISO_FILE=""
if [ -n "$1" ]; then
    ISO_FILE="$1"
else
    # Try to find the most recent ISO in output directory
    ISO_FILE=$(ls -t output/nubiferos-*.iso 2>/dev/null | head -1)
fi

if [ -z "$ISO_FILE" ] || [ ! -f "$ISO_FILE" ]; then
    echo "Error: ISO file not found"
    echo ""
    echo "Usage: $0 [path/to/iso]"
    echo ""
    echo "Or place ISO in output/ directory"
    exit 1
fi

echo "=========================================="
echo "QEMU with SPICE Support"
echo "=========================================="
echo "ISO: $ISO_FILE"
echo ""
echo "Features enabled:"
echo "  ✓ SPICE display server"
echo "  ✓ Clipboard sharing (bidirectional)"
echo "  ✓ QXL graphics driver"
echo "  ✓ USB redirection"
echo "  ✓ 4GB RAM"
echo "  ✓ 20GB virtual disk"
echo "  ✓ KVM acceleration"
echo ""
echo "Connect with:"
echo "  spicy --uri=spice://localhost:5930"
echo "  (or use virt-viewer)"
echo ""
echo "Clipboard:"
echo "  - Copy in guest: Ctrl+C"
echo "  - Paste in guest: Ctrl+V"
echo "  - Works automatically with SPICE client"
echo ""
echo "=========================================="
echo ""

# Check if KVM is available
KVM_OPTS=""
if [ -e /dev/kvm ] && [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
    echo "✓ KVM acceleration available"
    KVM_OPTS="-enable-kvm"
else
    echo "⚠ KVM not available - using software emulation (slower)"
fi

# Check if spice client is installed
if ! command -v spicy &> /dev/null && ! command -v remote-viewer &> /dev/null; then
    echo ""
    echo "⚠ SPICE client not found. Install with:"
    echo "  sudo apt install spice-client-gtk"
    echo "  or"
    echo "  sudo apt install virt-viewer"
    echo ""
fi

echo ""
echo "Starting QEMU..."
echo ""

# Create virtual disk if it doesn't exist
DISK_FILE="testing/nubiferos-test-disk.qcow2"
if [ ! -f "$DISK_FILE" ]; then
    echo "Creating 20GB virtual disk for testing..."
    qemu-img create -f qcow2 "$DISK_FILE" 20G
    echo "✓ Virtual disk created: $DISK_FILE"
fi

# Launch QEMU with SPICE
# Note: Using IDE interface for disk instead of virtio to ensure GRUB can install
# Virtio disks appear as /dev/vda which can cause GRUB installation issues
qemu-system-x86_64 \
    $KVM_OPTS \
    -drive file="$ISO_FILE",media=cdrom,readonly=on,format=raw,if=ide \
    -drive file="$DISK_FILE",format=qcow2,if=ide \
    -m 4096 \
    -smp 2 \
    -boot d \
    -vga qxl \
    -spice port=5930,addr=127.0.0.1,disable-ticketing=on \
    -device virtio-serial-pci \
    -device virtserialport,chardev=spicechannel0,name=com.redhat.spice.0 \
    -chardev spicevmc,id=spicechannel0,name=vdagent \
    -usb \
    -device usb-tablet \
    -device usb-kbd

echo ""
echo "QEMU exited"
