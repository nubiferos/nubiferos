#!/bin/bash
# Launch QEMU with VNC for easier remote access and log capture

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
echo "QEMU with VNC Support"
echo "=========================================="
echo "ISO: $ISO_FILE"
echo ""
echo "Features enabled:"
echo "  ✓ VNC server on :0 (port 5900)"
echo "  ✓ Serial console output to file"
echo "  ✓ 4GB RAM"
echo "  ✓ KVM acceleration"
echo ""
echo "Connect with:"
echo "  vncviewer localhost:0"
echo "  (or use any VNC client)"
echo ""
echo "Serial console log:"
echo "  tail -f /tmp/qemu-serial.log"
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

echo ""
echo "Starting QEMU..."
echo "VNC server will be available at localhost:5900"
echo ""

# Launch QEMU with VNC and serial console logging
qemu-system-x86_64 \
    $KVM_OPTS \
    -drive file="$ISO_FILE",media=cdrom,readonly=on,format=raw,if=ide \
    -m 4096 \
    -smp 2 \
    -boot d \
    -vnc :0 \
    -serial file:/tmp/qemu-serial.log \
    -usb \
    -device usb-tablet

echo ""
echo "QEMU exited"
echo "Serial console log saved to: /tmp/qemu-serial.log"
