#!/bin/bash
# Deep debugging script for Calamares segfault

echo "=========================================="
echo "Calamares Crash Debugging"
echo "=========================================="
echo ""

# Check logs to examine
echo "=== Logs to check ==="
echo ""
echo "1. System log (dmesg):"
echo "   sudo dmesg | tail -50"
echo ""
echo "2. X.org log:"
echo "   cat ~/.local/share/xorg/Xorg.0.log | tail -50"
echo "   OR: cat /var/log/Xorg.0.log | tail -50"
echo ""
echo "3. Journal (systemd):"
echo "   sudo journalctl -xe | tail -50"
echo ""
echo "4. Core dump (if enabled):"
echo "   coredumpctl list"
echo "   coredumpctl info calamares"
echo ""

# Run actual checks
echo "=== Running diagnostic checks ==="
echo ""

# Check 1: Get crash info from dmesg
echo "1. Checking kernel messages for segfault..."
sudo dmesg | grep -i "calamares\|segfault" | tail -10
echo ""

# Check 2: Check Qt libraries
echo "2. Checking Qt library dependencies..."
ldd $(which calamares) | grep -i qt
echo ""

# Check 3: Check for missing libraries
echo "3. Checking for missing libraries..."
if ldd $(which calamares) | grep "not found"; then
    echo "   ✗ MISSING LIBRARIES FOUND!"
else
    echo "   ✓ All libraries present"
fi
echo ""

# Check 4: Graphics driver info
echo "4. Checking graphics driver..."
lspci | grep -i vga
echo ""
glxinfo | grep "OpenGL renderer" || echo "   glxinfo not available (install mesa-utils)"
echo ""

# Check 5: Try running with different Qt platforms
echo "5. Testing different Qt platforms..."
echo ""

echo "   a) Testing with xcb platform..."
sudo QT_DEBUG_PLUGINS=1 QT_QPA_PLATFORM=xcb DISPLAY=$DISPLAY XAUTHORITY=$XAUTHORITY calamares 2>&1 | head -30 &
sleep 2
killall calamares 2>/dev/null
echo ""

echo "   b) Testing with offscreen platform (no display)..."
sudo QT_QPA_PLATFORM=offscreen calamares --help 2>&1 | head -10
echo ""

# Check 6: Run with gdb to get backtrace
echo "6. Getting backtrace with gdb..."
if command -v gdb &> /dev/null; then
    echo "   Running: gdb -batch -ex run -ex bt --args calamares"
    sudo gdb -batch -ex "set pagination off" -ex run -ex bt --args calamares 2>&1 | tail -50
else
    echo "   gdb not installed. Install with: sudo apt install gdb"
fi
echo ""

# Check 7: Strace to see system calls
echo "7. Checking system calls with strace..."
if command -v strace &> /dev/null; then
    echo "   Running strace (last 30 lines before crash)..."
    sudo strace -e trace=open,openat,access,stat calamares 2>&1 | tail -30 &
    sleep 2
    killall calamares 2>/dev/null
else
    echo "   strace not installed. Install with: sudo apt install strace"
fi
echo ""

echo "=========================================="
echo "Diagnostic complete"
echo "=========================================="
echo ""
echo "Common issues and fixes:"
echo ""
echo "1. Missing Qt platform plugin:"
echo "   sudo apt install libqt5gui5 qt5-qmake qtbase5-dev"
echo ""
echo "2. Graphics driver issues (VirtualBox):"
echo "   sudo apt install virtualbox-guest-x11 virtualbox-guest-utils"
echo "   sudo VBoxClient --display"
echo ""
echo "3. Missing Qt libraries:"
echo "   sudo apt install libkf5coreaddons5 libkf5config5 libkf5i18n5"
echo ""
echo "4. Try software rendering:"
echo "   sudo LIBGL_ALWAYS_SOFTWARE=1 calamares"
echo ""
