#!/bin/bash
# Debug script - run inside the VM to capture Calamares crash info
# This script disables reboots, starts X, runs Calamares, and dumps all output to serial

SERIAL=/dev/ttyS0

exec > >(tee $SERIAL) 2>&1

echo "=== CALAMARES DEBUG SESSION ==="
echo "Date: $(date)"
echo ""

# Disable all reboot mechanisms
echo "--- Disabling reboot mechanisms ---"
sed -i 's/reboot/true/g' /home/installer/.xinitrc /home/installer/.bash_logout /home/installer/.bash_profile 2>/dev/null
echo "Done"

# Check Calamares version
echo "--- Calamares version ---"
calamares --version 2>&1 || echo "Could not get version"

# Check Qt version
echo "--- Qt info ---"
python3 -c "import subprocess; subprocess.run(['calamares', '-v'], capture_output=True)" 2>&1 || true

# List Calamares config
echo "--- Calamares settings.conf ---"
cat /etc/calamares/settings.conf 2>/dev/null || echo "NOT FOUND"

echo ""
echo "--- Calamares modules directory ---"
ls -la /etc/calamares/modules/ 2>/dev/null || echo "NOT FOUND"

echo ""
echo "--- Starting X server ---"
X :0 -config /dev/null -nolisten tcp vt7 &
X_PID=$!
sleep 2

if ! kill -0 $X_PID 2>/dev/null; then
    echo "ERROR: X server failed to start"
    echo "--- Xorg log ---"
    cat /var/log/Xorg.0.log 2>/dev/null || cat /home/installer/.local/share/xorg/Xorg.0.log 2>/dev/null || echo "No Xorg log found"
    exit 1
fi

echo "X server started (PID: $X_PID)"
export DISPLAY=:0

echo ""
echo "=== RUNNING CALAMARES (attempt 1: software rendering) ==="
echo ""
QT_QUICK_BACKEND=software LIBGL_ALWAYS_SOFTWARE=1 calamares -d 2>&1
CAL_EXIT=$?
echo ""
echo "=== CALAMARES EXITED WITH CODE: $CAL_EXIT ==="

if [ $CAL_EXIT -eq 139 ]; then
    echo "*** SEGMENTATION FAULT DETECTED ***"
    echo ""
    echo "=== RUNNING CALAMARES (attempt 2: no software rendering) ==="
    calamares -d 2>&1
    CAL_EXIT2=$?
    echo "=== ATTEMPT 2 EXITED WITH CODE: $CAL_EXIT2 ==="
fi

echo ""
echo "--- dmesg tail (crash info) ---"
dmesg | tail -30

echo ""
echo "--- Xorg log errors ---"
grep -E "EE|error|Error" /home/installer/.local/share/xorg/Xorg.0.log 2>/dev/null || echo "No errors in Xorg log"

# Kill X
kill $X_PID 2>/dev/null

echo ""
echo "=== DEBUG SESSION COMPLETE ==="
echo "Sleeping forever (VM stays up for inspection)"
sleep 999999
