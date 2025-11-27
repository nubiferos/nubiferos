#!/bin/bash
# Simple QEMU launcher with display window

set -e

ISO_FILE=""
if [ -n "$1" ]; then
    ISO_FILE="$1"
else
    ISO_FILE=$(ls -t output/nubiferos-*.iso 2>/dev/null | head -1)
fi

if [ -z "$ISO_FILE" ] || [ ! -f "$ISO_FILE" ]; then
    echo "Error: ISO file not found"
    echo "Usage: $0 [path/to/iso]"
    exit 1
fi

echo "=========================================="
echo "QEMU Simple Launcher"
echo "=========================================="
echo "ISO: $ISO_FILE"
echo ""

KVM_OPTS=""
if [ -e /dev/kvm ]; then
    echo "✓ KVM acceleration enabled"
    KVM_OPTS="-enable-kvm"
else
    echo "⚠ KVM not available"
fi

echo ""
echo "Starting QEMU with display window..."
echo ""

# Note: Using -drive instead of -cdrom to avoid format warnings
# readonly=on prevents file locking issues
qemu-system-x86_64 \
    $KVM_OPTS \
    -drive file="$ISO_FILE",media=cdrom,readonly=on,format=raw,if=ide \
    -m 4096 \
    -smp 2 \
    -boot d \
    -usb \
    -device usb-tablet
