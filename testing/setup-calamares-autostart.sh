#!/bin/bash
# Manually set up Calamares autostart for current user
# Run this if Calamares isn't launching automatically

echo "=========================================="
echo "Calamares Autostart Setup"
echo "=========================================="
echo ""
echo "Current user: $(whoami)"
echo "Home directory: $HOME"
echo ""

# Create autostart directory
echo "Creating autostart directory..."
mkdir -p ~/.config/autostart

# Create desktop entry
echo "Creating Calamares autostart entry..."
cat > ~/.config/autostart/calamares.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Install NubiferOS
Comment=System Installer
Exec=pkexec calamares
Icon=calamares
Terminal=false
Categories=System;
X-GNOME-Autostart-enabled=true
EOF

# Verify
if [ -f ~/.config/autostart/calamares.desktop ]; then
    echo "✓ Autostart file created successfully"
    echo ""
    echo "File location: ~/.config/autostart/calamares.desktop"
    echo ""
    echo "To activate:"
    echo "  1. Log out"
    echo "  2. Log back in"
    echo "  3. Calamares should launch automatically"
    echo ""
    echo "Or launch now with: pkexec calamares"
else
    echo "✗ Failed to create autostart file"
    exit 1
fi

echo ""
echo "=========================================="
