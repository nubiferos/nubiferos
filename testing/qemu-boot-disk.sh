#!/bin/bash
# Boot from installed disk (no ISO)

set -e

echo "=========================================="
echo "QEMU - Boot from Installed Disk"
echo "=========================================="
echo ""

# Check if disk exists
DISK_FILE="testing/nubiferos-test-disk.qcow2"
if [ ! -f "$DISK_FILE" ]; then
    echo "Error: Virtual disk not found: $DISK_FILE"
    echo "Run qemu-with-spice.sh first to install the system"
    exit 1
fi

echo "Disk: $DISK_FILE"
echo ""
echo "Features enabled:"
echo "  ✓ SPICE display server"
echo "  ✓ Clipboard sharing (bidirectional)"
echo "  ✓ QXL graphics driver"
echo "  ✓ USB redirection"
echo "  ✓ 4GB RAM"
echo "  ✓ KVM acceleration"
echo ""
echo "Connect with:"
echo "  spicy --uri=spice://localhost:5930"
echo "  (or use virt-viewer)"
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
echo "Starting QEMU (booting from disk)..."
echo ""

# Launch QEMU - boot from hard disk (no ISO)
qemu-system-x86_64 \
    $KVM_OPTS \
    -drive file="$DISK_FILE",format=qcow2,if=ide \
    -m 4096 \
    -smp 2 \
    -boot c \
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
