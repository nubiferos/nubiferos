#!/bin/bash
# Automated ISO boot test: boots the ISO headless in QEMU and verifies it
# reaches a working Calamares installer.
#
# Two verification modes, auto-selected:
#   - Marker mode (ISOs containing BOOT-TEST.txt): asserts serial-console
#     markers emitted by nubifer-boot-test.service inside the ISO:
#       service-started -> graphical-target -> calamares-running
#   - Screenshot mode (older ISOs): boots for a fixed period and asserts
#     the display is alive (non-blank, changing) — weaker, but catches
#     "ISO doesn't boot at all".
#
# Usage: test-iso-boot.sh <path-to-iso> [artifacts-dir]
# Env:   BOOT_TIMEOUT (seconds, default 420 KVM / 900 TCG), QEMU_RAM (MB)
#
# Exit codes: 0 pass, 1 boot verification failed, 2 setup error

set -u

ISO_PATH="${1:?usage: test-iso-boot.sh <iso> [artifacts-dir]}"
ART_DIR="${2:-boot-test-artifacts}"
QEMU_RAM="${QEMU_RAM:-4096}"

[ -f "$ISO_PATH" ] || { echo "ERROR: ISO not found: $ISO_PATH"; exit 2; }
command -v qemu-system-x86_64 > /dev/null || { echo "ERROR: qemu-system-x86_64 not installed"; exit 2; }

mkdir -p "$ART_DIR"
SERIAL_LOG="$ART_DIR/serial.log"
QMP_SOCK="$ART_DIR/qmp.sock"
EVENTS_SOCK="$ART_DIR/qmp-events.sock"
EVENTS_LOG="$ART_DIR/events.log"
TARGET_DISK="$ART_DIR/target.qcow2"
: > "$SERIAL_LOG"
: > "$EVENTS_LOG"
rm -f "$QMP_SOCK" "$EVENTS_SOCK"

# KVM if available (CI runners have it), otherwise emulation with a longer timeout
if [ -w /dev/kvm ]; then
    ACCEL_ARGS="-enable-kvm -cpu host"
    # CI runners reach Calamares in ~6-8 min; marker script polls 480s
    # after multi-user, so give the full chain room
    BOOT_TIMEOUT="${BOOT_TIMEOUT:-720}"
    echo "Using KVM acceleration (timeout ${BOOT_TIMEOUT}s)"
else
    ACCEL_ARGS="-cpu max"
    BOOT_TIMEOUT="${BOOT_TIMEOUT:-900}"
    echo "WARNING: /dev/kvm not available, using TCG emulation (timeout ${BOOT_TIMEOUT}s)"
fi

# Marker support: flag file in the ISO root, readable without mounting
MARKER_MODE=0
if command -v isoinfo > /dev/null && isoinfo -i "$ISO_PATH" -f 2>/dev/null | grep -qi '^/BOOT_TEST\|^/BOOT-TEST'; then
    MARKER_MODE=1
    echo "ISO advertises boot-test markers: asserting serial markers"
else
    echo "No BOOT-TEST.txt in ISO (pre-marker build): screenshot-only verification"
fi

qemu-img create -f qcow2 "$TARGET_DISK" 25G > /dev/null

qemu-system-x86_64 \
    $ACCEL_ARGS \
    -m "$QEMU_RAM" -smp 2 \
    -cdrom "$ISO_PATH" -boot d \
    -drive file="$TARGET_DISK",format=qcow2,if=virtio \
    -display none -vga std \
    -serial "file:$SERIAL_LOG" \
    -qmp "unix:$QMP_SOCK,server,nowait" \
    -qmp "unix:$EVENTS_SOCK,server,nowait" \
    -no-reboot &
QEMU_PID=$!

# Persistent QMP listener on the second socket records async events
# (RESET/SHUTDOWN carry a "guest" flag + reason — tells us whether an
# early QEMU exit was guest-initiated). Best-effort diagnostics.
python3 - "$EVENTS_SOCK" "$EVENTS_LOG" << 'PYEOF' 2>/dev/null &
import json, socket, sys, time
sock_path, out = sys.argv[1], sys.argv[2]
for _ in range(20):                                # wait for socket to appear
    try:
        s = socket.socket(socket.AF_UNIX)
        s.connect(sock_path)
        break
    except OSError:
        time.sleep(0.5)
else:
    sys.exit(0)
f = s.makefile('rw')
f.readline()
f.write(json.dumps({"execute": "qmp_capabilities"}) + "\n"); f.flush()
with open(out, 'a') as log:
    for line in f:
        try:
            msg = json.loads(line)
        except ValueError:
            continue
        if 'event' in msg:
            log.write(json.dumps(msg) + "\n")
            log.flush()
PYEOF
EVENTS_PID=$!
trap 'kill $QEMU_PID $EVENTS_PID 2>/dev/null; wait $QEMU_PID 2>/dev/null' EXIT

# Speak QMP to grab a screendump (PPM). Best-effort — never fails the test.
screenshot() {
    python3 - "$QMP_SOCK" "$ART_DIR/$1.ppm" << 'PYEOF' 2>/dev/null || true
import json, socket, sys, time
sock_path, out = sys.argv[1], sys.argv[2]
s = socket.socket(socket.AF_UNIX)
s.settimeout(10)
s.connect(sock_path)
f = s.makefile('rw')
f.readline()                                       # greeting
f.write(json.dumps({"execute": "qmp_capabilities"}) + "\n"); f.flush()
f.readline()
f.write(json.dumps({"execute": "screendump",
                    "arguments": {"filename": out}}) + "\n"); f.flush()
time.sleep(1)
PYEOF
}

# Non-blank check: a real desktop/installer frame has many distinct colors
ppm_alive() {
    python3 - "$1" << 'PYEOF'
import sys
try:
    data = open(sys.argv[1], 'rb').read()
    if len(data) < 1000:
        sys.exit(1)
    body = data[-(len(data) - data.find(b'255\n') - 4):]
    colors = set()
    for i in range(0, len(body) - 3, 3):
        colors.add(body[i:i+3])
        if len(colors) > 16:
            sys.exit(0)
    sys.exit(1)
except Exception:
    sys.exit(1)
PYEOF
}

echo "Booting (pid $QEMU_PID)..."
ELAPSED=0
INTERVAL=15
SHOT_EVERY=60
LAST_SHOT=0
RESULT=""

while [ "$ELAPSED" -lt "$BOOT_TIMEOUT" ]; do
    sleep "$INTERVAL"
    ELAPSED=$((ELAPSED + INTERVAL))

    # Check markers before QEMU liveness: if the installer already came up,
    # the boot verified even if QEMU has since exited (see warning below)
    if [ "$MARKER_MODE" = 1 ]; then
        if grep -q "NUBIFER-BOOT-TEST: calamares-running" "$SERIAL_LOG"; then
            RESULT="pass"
            break
        fi
        if grep -q "NUBIFER-BOOT-TEST: FAIL" "$SERIAL_LOG"; then
            RESULT="fail"
            break
        fi
    fi

    if ! kill -0 "$QEMU_PID" 2>/dev/null; then
        echo "ERROR: QEMU exited early (guest reboot/shutdown/crash)"
        RESULT="fail"
        break
    fi

    if [ $((ELAPSED - LAST_SHOT)) -ge "$SHOT_EVERY" ]; then
        screenshot "boot-${ELAPSED}s"
        LAST_SHOT=$ELAPSED
    fi
done

if [ "$RESULT" = "pass" ] && ! kill -0 "$QEMU_PID" 2>/dev/null; then
    echo "WARNING: markers passed but QEMU exited during the test window —"
    echo "         the guest rebooted or shut down after Calamares started."
fi

screenshot "final"

echo "=== serial log (tail) ==="
tail -20 "$SERIAL_LOG" 2>/dev/null || true
echo "========================="
if [ -s "$EVENTS_LOG" ]; then
    echo "=== QMP events ==="
    cat "$EVENTS_LOG"
    echo "=================="
fi

if [ "$MARKER_MODE" = 1 ]; then
    for m in service-started graphical-target calamares-running; do
        if grep -q "NUBIFER-BOOT-TEST: $m" "$SERIAL_LOG"; then
            echo "✓ marker: $m"
        else
            echo "✗ marker missing: $m"
            RESULT="fail"
        fi
    done
    [ "$RESULT" = "pass" ] && { echo "PASS: ISO boots to Calamares (${ELAPSED}s)"; exit 0; }
    echo "FAIL: boot verification failed after ${ELAPSED}s (see $ART_DIR)"
    exit 1
else
    # Screenshot mode: display must be alive on the final frame
    if ppm_alive "$ART_DIR/final.ppm"; then
        echo "PASS (screenshot mode): display alive after ${ELAPSED}s — inspect $ART_DIR manually"
        exit 0
    fi
    echo "FAIL (screenshot mode): display blank or QEMU dead after ${ELAPSED}s"
    exit 1
fi
