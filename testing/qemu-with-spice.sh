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
echo "  ✓ UEFI firmware (OVMF)"
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

# Handle virtual disk
DISK_FILE="testing/nubiferos-test-disk.qcow2"
if [ -f "$DISK_FILE" ]; then
    echo "⚠ Existing virtual disk found: $DISK_FILE"
    echo ""
    read -p "Delete existing disk and start fresh? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm "$DISK_FILE"
        echo "✓ Old disk deleted"
        echo ""
    else
        echo "Using existing disk (may have old installation)"
        echo ""
    fi
fi

if [ ! -f "$DISK_FILE" ]; then
    echo "Creating 20GB virtual disk for testing..."
    qemu-img create -f qcow2 "$DISK_FILE" 20G
    echo "✓ Virtual disk created: $DISK_FILE"
    echo ""
fi

# Check for OVMF firmware
OVMF_CODE="/usr/share/OVMF/OVMF_CODE_4M.fd"
OVMF_VARS="testing/OVMF_VARS.fd"

if [ ! -f "$OVMF_CODE" ]; then
    # Try alternative path
    OVMF_CODE="/usr/share/OVMF/OVMF_CODE.fd"
    if [ ! -f "$OVMF_CODE" ]; then
        echo "Error: OVMF firmware not found"
        echo "Install with: sudo apt install ovmf"
        exit 1
    fi
fi

# Create OVMF_VARS if it doesn't exist
if [ ! -f "$OVMF_VARS" ]; then
    echo "Creating UEFI variables file..."
    # Try 4M version first, fall back to regular
    if [ -f "/usr/share/OVMF/OVMF_VARS_4M.fd" ]; then
        cp /usr/share/OVMF/OVMF_VARS_4M.fd "$OVMF_VARS"
    else
        cp /usr/share/OVMF/OVMF_VARS.fd "$OVMF_VARS"
    fi
    echo "✓ UEFI variables created"
    echo ""
fi

# Launch QEMU with UEFI and SPICE
qemu-system-x86_64 \
    $KVM_OPTS \
    -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE" \
    -drive if=pflash,format=raw,file="$OVMF_VARS" \
    -drive file="$ISO_FILE",media=cdrom,readonly=on,format=raw \
    -drive file="$DISK_FILE",format=qcow2,if=virtio \
    -m 4096 \
    -smp 2 \
    -boot order=d \
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
