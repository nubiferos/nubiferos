#!/bin/bash
# Diagnostic script to check why Calamares is segfaulting

echo "=========================================="
echo "Calamares Diagnostic Script"
echo "=========================================="
echo ""

# Check 1: Is Calamares installed?
echo "1. Checking Calamares installation..."
if command -v calamares &> /dev/null; then
    echo "   ✓ Calamares is installed"
    calamares --version 2>&1 || echo "   ⚠️  Version check failed"
else
    echo "   ✗ Calamares NOT installed"
    exit 1
fi
echo ""

# Check 2: Required packages
echo "2. Checking required packages..."
REQUIRED_PACKAGES=(
    "sudo"
    "policykit-1"
    "polkitd"
    "libpolkit-qt5-1-1"
    "libkf5coreaddons5"
    "libqt5core5a"
    "libqt5gui5"
    "libqt5widgets5"
)

for pkg in "${REQUIRED_PACKAGES[@]}"; do
    if dpkg -l | grep -q "^ii  $pkg"; then
        echo "   ✓ $pkg installed"
    else
        echo "   ✗ $pkg MISSING"
    fi
done
echo ""

# Check 3: Configuration files
echo "3. Checking configuration files..."
CONFIG_FILES=(
    "/etc/calamares/settings.conf"
    "/etc/calamares/modules/welcome.conf"
    "/etc/calamares/modules/partition.conf"
    "/etc/calamares/modules/users.conf"
)

for file in "${CONFIG_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "   ✓ $file exists"
    else
        echo "   ✗ $file MISSING"
    fi
done
echo ""

# Check 4: Branding files
echo "4. Checking branding files..."
if [ -d "/etc/calamares/branding/nubiferos" ]; then
    echo "   ✓ Branding directory exists"
    
    BRANDING_FILES=(
        "/etc/calamares/branding/nubiferos/branding.desc"
        "/etc/calamares/branding/nubiferos/stylesheet.qss"
    )
    
    for file in "${BRANDING_FILES[@]}"; do
        if [ -f "$file" ]; then
            echo "   ✓ $(basename $file) exists"
        else
            echo "   ✗ $(basename $file) MISSING"
        fi
    done
else
    echo "   ✗ Branding directory missing"
fi
echo ""

# Check 5: Library dependencies
echo "5. Checking library dependencies..."
if ldd $(which calamares) | grep -q "not found"; then
    echo "   ✗ Missing library dependencies:"
    ldd $(which calamares) | grep "not found"
else
    echo "   ✓ All library dependencies satisfied"
fi
echo ""

# Check 6: Run with debug output
echo "6. Attempting to run Calamares with debug output..."
echo "   (This will show the actual error)"
echo ""
echo "   Running: calamares -d 2>&1 | head -50"
echo "   ----------------------------------------"

# Create runtime dir if it doesn't exist
sudo mkdir -p /tmp/runtime-root
sudo chmod 700 /tmp/runtime-root

# Try to run with debug
sudo XDG_RUNTIME_DIR=/tmp/runtime-root \
     DISPLAY=$DISPLAY \
     XAUTHORITY=$XAUTHORITY \
     calamares -d 2>&1 | head -50

echo ""
echo "=========================================="
echo "Diagnostic Complete"
echo "=========================================="
echo ""
echo "If you see errors above, they indicate what's wrong."
echo "Common issues:"
echo "  - Missing polkit/sudo packages (fixed in new ISO)"
echo "  - Missing branding files (fixed in new ISO)"
echo "  - Qt library issues"
echo ""
