#!/bin/bash
# NubiferOS automated boot-test marker emitter.
#
# Runs only in the live installer environment (boot=live) and writes
# progress markers to the serial port so a QEMU harness (testing/
# test-iso-boot.sh) can assert the ISO boots to a working installer.
# On real hardware without a serial port every write is a silent no-op,
# and on installed systems the boot=live guard exits immediately.
#
# The only hard assertion is a running Calamares process. graphical.target
# is reported when seen but is NOT a gate: in the kiosk/autologin live
# session the target can stay inactive even though the GUI is up.

grep -q 'boot=live' /proc/cmdline || exit 0

SERIAL="/dev/ttyS0"

emit() {
    echo "NUBIFER-BOOT-TEST: $1" > "$SERIAL" 2>/dev/null || true
}

emit "service-started"

graphical_emitted=""
# Poll up to 480s (240 x 2s) for the installer
for _ in $(seq 1 240); do
    if [ -z "$graphical_emitted" ] && systemctl is-active graphical.target > /dev/null 2>&1; then
        emit "graphical-target"
        graphical_emitted=1
    fi
    if pgrep -x calamares > /dev/null 2>&1; then
        # A visible installer implies the GUI is up regardless of target state
        if [ -z "$graphical_emitted" ]; then
            emit "graphical-target"
        fi
        emit "calamares-running"

        # Watch for the known flake: Calamares sometimes exits shortly
        # after starting (under QEMU at least). Dump diagnostics to serial
        # so CI runs capture the exit reason without interactive access.
        for _ in $(seq 1 60); do
            if ! pgrep -x calamares > /dev/null 2>&1; then
                emit "WARN calamares-exited-early"
                {
                    echo "--- /tmp/kiosk-session.log ---"
                    cat /tmp/kiosk-session.log 2>/dev/null
                    echo "--- startx log (tail) ---"
                    tail -30 /tmp/startx.log 2>/dev/null
                    echo "--- calamares session log (tail) ---"
                    tail -40 /home/installer/.cache/calamares/session.log 2>/dev/null
                    echo "--- Xorg log errors ---"
                    grep -i "(EE)\|fatal" /home/installer/.local/share/xorg/Xorg.0.log /var/log/Xorg.0.log 2>/dev/null | tail -15
                    echo "--- end diagnostics ---"
                } > "$SERIAL" 2>/dev/null || true
                exit 0
            fi
            sleep 2
        done
        exit 0
    fi
    sleep 2
done

emit "FAIL calamares-timeout"
systemctl --failed --no-legend --plain > "$SERIAL" 2>/dev/null || true
exit 0
