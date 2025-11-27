#!/bin/bash
# Launch QEMU with comprehensive logging for debugging

set -e

# Find the ISO file
ISO_FILE=""
if [ -n "$1" ]; then
    ISO_FILE="$1"
else
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

# Generate timestamped log file in /tmp (avoids permission issues)
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="/tmp/qemu-boot_${TIMESTAMP}.log"

echo "=========================================="
echo "QEMU with Comprehensive Logging"
echo "=========================================="
echo "ISO: $ISO_FILE"
echo "Log file: $LOG_FILE"
echo ""
echo "Features enabled:"
echo "  ✓ Serial console → $LOG_FILE"
echo "  ✓ QEMU monitor"
echo "  ✓ 4GB RAM"
echo "  ✓ KVM acceleration"
echo ""
echo "To view logs (real-time in another terminal):"
echo "  tail -f $LOG_FILE"
echo ""
echo "To copy logs after boot:"
echo "  cat $LOG_FILE"
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
echo "Press Ctrl+Alt+2 to access QEMU monitor"
echo "Press Ctrl+Alt+1 to return to VM display"
echo ""

# Launch QEMU with logging
qemu-system-x86_64 \
    $KVM_OPTS \
    -drive file="$ISO_FILE",media=cdrom,readonly=on,format=raw,if=ide \
    -m 4096 \
    -smp 2 \
    -boot d \
    -serial file:"$LOG_FILE" \
    -usb \
    -device usb-tablet

echo ""
echo "=========================================="
echo "QEMU exited"
echo "=========================================="
echo ""
echo "Boot log saved to: $LOG_FILE"
echo ""
echo "To view the log:"
echo "  cat $LOG_FILE"
echo ""
echo "To search for errors:"
echo "  grep -i error $LOG_FILE"
echo "  grep -i calamares $LOG_FILE"
echo ""
