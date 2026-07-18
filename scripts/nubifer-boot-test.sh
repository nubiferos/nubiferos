#!/bin/bash
# NubiferOS automated boot-test marker emitter.
#
# Runs only in the live installer environment (boot=live) and writes
# progress markers to the serial port so a QEMU harness (testing/
# test-iso-boot.sh) can assert the ISO boots to a working installer.
# On real hardware without a serial port every write is a silent no-op,
# and on installed systems the boot=live guard exits immediately.

grep -q 'boot=live' /proc/cmdline || exit 0

SERIAL="/dev/ttyS0"

emit() {
    echo "NUBIFER-BOOT-TEST: $1" > "$SERIAL" 2>/dev/null || true
}

emit "service-started"

# Stage 1: graphical target (GDM/session up)
reached_graphical=""
for _ in $(seq 1 120); do
    if systemctl is-active graphical.target > /dev/null 2>&1; then
        reached_graphical=1
        emit "graphical-target"
        break
    fi
    sleep 2
done

if [ -z "$reached_graphical" ]; then
    emit "FAIL graphical-target-timeout"
    systemctl --failed --no-legend --plain > "$SERIAL" 2>/dev/null || true
    exit 0
fi

# Stage 2: Calamares installer process visible
for _ in $(seq 1 90); do
    if pgrep -x calamares > /dev/null 2>&1; then
        emit "calamares-running"
        exit 0
    fi
    sleep 2
done

emit "FAIL calamares-timeout"
systemctl --failed --no-legend --plain > "$SERIAL" 2>/dev/null || true
exit 0
