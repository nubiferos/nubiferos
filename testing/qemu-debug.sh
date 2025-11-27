#!/bin/bash
# Launch QEMU with comprehensive logging for debugging

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

mkdir -p logs/qemu
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="logs/qemu/boot_${TIMESTAMP}.log"

echo "=========================================="
echo "QEMU Debug Mode"
echo "=========================================="
echo "ISO: $ISO_FILE"
echo "Log: $LOG_FILE"
echo ""
echo "View logs in another terminal:"
echo "  tail -f $LOG_FILE"
echo ""
echo "=========================================="

KVM_OPTS=""
if [ -e /dev/kvm ]; then
    KVM_OPTS="-enable-kvm"
fi

qemu-system-x86_64 \
    $KVM_OPTS \
    -cdrom "$ISO_FILE" \
    -m 4096 \
    -smp 2 \
    -boot d \
    -serial file:"$LOG_FILE" \
    -usb \
    -device usb-tablet \
    "$@"

echo ""
echo "Log saved: $LOG_FILE"
echo "View with: cat $LOG_FILE"
