#!/bin/bash
# Test script to verify Calamares installer configuration
# Run this inside the live environment to test the installer

set -e

echo "=========================================="
echo "Calamares Installer Test Script"
echo "=========================================="
echo ""

# Check if Calamares is installed
echo "1. Checking if Calamares is installed..."
if command -v calamares &> /dev/null; then
    echo "   ✓ Calamares is installed"
    calamares --version
else
    echo "   ✗ Calamares is NOT installed"
    exit 1
fi

echo ""

# Check configuration files
echo "2. Checking configuration files..."
if [ -f /etc/calamares/settings.conf ]; then
    echo "   ✓ settings.conf exists"
else
    echo "   ✗ settings.conf missing"
fi

if [ -d /etc/calamares/modules ]; then
    echo "   ✓ modules directory exists"
    echo "   Modules found:"
    ls -1 /etc/calamares/modules/ | sed 's/^/     - /'
else
    echo "   ✗ modules directory missing"
fi

if [ -d /etc/calamares/branding ]; then
    echo "   ✓ branding directory exists"
else
    echo "   ✗ branding directory missing"
fi

echo ""

# Check for autostart configuration
echo "3. Checking autostart configuration..."
if [ -f /etc/xdg/autostart/calamares.desktop ]; then
    echo "   ✓ System autostart exists"
elif [ -f ~/.config/autostart/calamares.desktop ]; then
    echo "   ✓ User autostart exists"
else
    echo "   ✗ No autostart configuration found"
    echo "   This is why Calamares doesn't launch automatically!"
fi

echo ""

# Check desktop entry
echo "4. Checking desktop entry..."
if [ -f /usr/share/applications/calamares.desktop ]; then
    echo "   ✓ Desktop entry exists"
    echo "   You can launch manually from applications menu"
else
    echo "   ✗ Desktop entry missing"
fi

echo ""

# Test launch
echo "5. Testing Calamares launch..."
echo "   Attempting to launch Calamares..."
echo "   (This will open the installer GUI)"
echo ""
echo "   Press Ctrl+C to cancel, or Enter to continue..."
read

# Launch Calamares
if [ "$EUID" -eq 0 ]; then
    calamares
else
    pkexec calamares
fi
