#!/bin/bash
# Test QEMU launch and show diagnostics

ISO_FILE="${1:-iso/NubiferOS-1.0-amd64.iso}"

echo "=========================================="
echo "QEMU Diagnostic Test"
echo "=========================================="
echo ""
echo "Checking environment..."
echo "  DISPLAY: $DISPLAY"
echo "  XDG_SESSION_TYPE: $XDG_SESSION_TYPE"
echo "  ISO: $ISO_FILE"
echo ""

if [ ! -f "$ISO_FILE" ]; then
    echo "❌ ISO file not found: $ISO_FILE"
    exit 1
fi
echo "✓ ISO file exists"

if [ -e /dev/kvm ]; then
    echo "✓ KVM available"
    KVM_OPTS="-enable-kvm"
else
    echo "⚠ KVM not available"
    KVM_OPTS=""
fi

if [ -z "$DISPLAY" ]; then
    echo "❌ No DISPLAY set - QEMU window won't open"
    echo "   Use VNC or SPICE scripts instead"
    exit 1
fi
echo "✓ DISPLAY is set"

echo ""
echo "Launching QEMU in background..."
echo "  (Check for a new window)"
echo ""

# Launch in background and capture PID
qemu-system-x86_64 \
    $KVM_OPTS \
    -drive file="$ISO_FILE",media=cdrom,readonly=on,format=raw,if=ide \
    -m 4096 \
    -smp 2 \
    -boot d \
    -usb \
    -device usb-tablet \
    2>&1 | grep -v "CPUID.*svm" &

QEMU_PID=$!

sleep 2

if ps -p $QEMU_PID > /dev/null 2>&1; then
    echo "✓ QEMU is running (PID: $QEMU_PID)"
    echo ""
    echo "To stop it:"
    echo "  kill $QEMU_PID"
    echo "  or use: ./testing/qemu-manager.sh killall"
    echo ""
    echo "Waiting for QEMU to exit..."
    wait $QEMU_PID
else
    echo "❌ QEMU failed to start or exited immediately"
    echo ""
    echo "Try running manually to see errors:"
    echo "  ./testing/qemu-simple.sh $ISO_FILE"
fi
