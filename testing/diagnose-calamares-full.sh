#!/bin/bash
# Comprehensive Calamares diagnostic script
# Run this in the live environment to diagnose issues

echo "=========================================="
echo "Calamares Diagnostic Tool"
echo "=========================================="
echo ""

# Check 1: Is Calamares installed?
echo "1. Checking Calamares installation..."
if command -v calamares &> /dev/null; then
    echo "   ✓ Calamares is installed"
    calamares --version 2>/dev/null || echo "   (version check failed)"
else
    echo "   ✗ Calamares NOT installed"
    exit 1
fi
echo ""

# Check 2: QML modules
echo "2. Checking QML modules..."
QML_MISSING=0
for module in qtquick2 qtquick-controls qtquick-controls2 qtquick-layouts qtquick-window2; do
    if dpkg -l | grep -q "qml-module-$module"; then
        echo "   ✓ qml-module-$module"
    else
        echo "   ✗ qml-module-$module MISSING"
        QML_MISSING=1
    fi
done
echo ""

# Check 3: XDG_RUNTIME_DIR
echo "3. Checking XDG_RUNTIME_DIR..."
echo "   Current user: $(whoami) (UID: $(id -u))"
echo "   XDG_RUNTIME_DIR: ${XDG_RUNTIME_DIR:-NOT SET}"

if [ -d "/run/user/$(id -u)" ]; then
    echo "   ✓ /run/user/$(id -u) exists"
    ls -la "/run/user/$(id -u)" | head -3
else
    echo "   ✗ /run/user/$(id -u) does NOT exist"
fi

if [ -d "/run/user/0" ]; then
    echo "   ✓ /run/user/0 (root) exists"
else
    echo "   ✗ /run/user/0 (root) does NOT exist"
fi
echo ""

# Check 4: Display server
echo "4. Checking display server..."
if [ -n "$WAYLAND_DISPLAY" ]; then
    echo "   ✓ Wayland: $WAYLAND_DISPLAY"
elif [ -n "$DISPLAY" ]; then
    echo "   ✓ X11: $DISPLAY"
else
    echo "   ✗ No display server detected"
fi
echo ""

# Check 5: Systemd services
echo "5. Checking systemd services..."
if systemctl list-unit-files | grep -q calamares; then
    echo "   Calamares services:"
    systemctl list-unit-files | grep calamares | sed 's/^/   /'
else
    echo "   No Calamares systemd services found"
fi
echo ""

# Check 6: Autostart files
echo "6. Checking autostart files..."
if [ -f "$HOME/.config/autostart/calamares.desktop" ]; then
    echo "   ✓ User autostart exists: $HOME/.config/autostart/calamares.desktop"
else
    echo "   ✗ User autostart missing"
fi

if [ -f "/etc/xdg/autostart/calamares.desktop" ]; then
    echo "   ✓ System autostart exists: /etc/xdg/autostart/calamares.desktop"
else
    echo "   ✗ System autostart missing"
fi
echo ""

# Check 7: Recent errors
echo "7. Checking recent errors..."
echo "   Last 10 Calamares-related journal entries:"
journalctl -xe --no-pager | grep -i calamares | tail -10 | sed 's/^/   /'
echo ""

# Check 8: Library dependencies
echo "8. Checking library dependencies..."
MISSING_LIBS=$(ldd /usr/bin/calamares 2>/dev/null | grep "not found" | wc -l)
if [ "$MISSING_LIBS" -eq 0 ]; then
    echo "   ✓ All libraries found"
else
    echo "   ✗ Missing $MISSING_LIBS libraries:"
    ldd /usr/bin/calamares | grep "not found" | sed 's/^/   /'
fi
echo ""

# Summary
echo "=========================================="
echo "Summary"
echo "=========================================="
if [ "$QML_MISSING" -eq 0 ] && [ -d "/run/user/0" ] && [ -n "$DISPLAY" ]; then
    echo "✓ System looks ready for Calamares"
    echo ""
    echo "Try launching with:"
    echo "  ./testing/launch-calamares.sh"
    echo "or"
    echo "  ./testing/quick-calamares-test.sh"
else
    echo "✗ Issues detected - see above"
    echo ""
    echo "Quick fixes:"
    if [ "$QML_MISSING" -eq 1 ]; then
        echo "  - Install missing QML modules"
    fi
    if [ ! -d "/run/user/0" ]; then
        echo "  - Create runtime dir: sudo mkdir -p /run/user/0 && sudo chmod 700 /run/user/0"
    fi
    if [ -z "$DISPLAY" ]; then
        echo "  - Ensure you're in a graphical session"
    fi
fi
echo ""
