#!/bin/bash
# NubiferOS Context Indicator Installation Script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXTENSION_UUID="nubiferos-context@nubiferos.org"
EXTENSION_DIR="$HOME/.local/share/gnome-shell/extensions/$EXTENSION_UUID"
PROFILE_D="/etc/profile.d"

echo "Installing NubiferOS Context Indicator..."

# Check if GNOME Shell is available
if ! command -v gnome-shell &> /dev/null; then
    echo "Warning: GNOME Shell not found. Extension will be installed but may not work."
fi

# Install GNOME Shell Extension
echo "Installing GNOME Shell extension..."
mkdir -p "$EXTENSION_DIR"

cp "$SCRIPT_DIR/gnome-extension/extension.js" "$EXTENSION_DIR/"
cp "$SCRIPT_DIR/gnome-extension/sessionState.js" "$EXTENSION_DIR/"
cp "$SCRIPT_DIR/gnome-extension/metadata.json" "$EXTENSION_DIR/"
cp "$SCRIPT_DIR/gnome-extension/stylesheet.css" "$EXTENSION_DIR/"

echo "✓ Extension files copied to $EXTENSION_DIR"

# Enable extension
if command -v gnome-extensions &> /dev/null; then
    echo "Enabling extension..."
    gnome-extensions enable "$EXTENSION_UUID" 2>/dev/null || true
    echo "✓ Extension enabled"
else
    echo "Note: gnome-extensions command not found. Enable manually with:"
    echo "  gnome-extensions enable $EXTENSION_UUID"
fi

# Install terminal prompt integration
if [ "$EUID" -eq 0 ]; then
    echo "Installing terminal prompt integration..."
    cp "$SCRIPT_DIR/nubiferos-prompt.sh" "$PROFILE_D/"
    chmod +x "$PROFILE_D/nubiferos-prompt.sh"
    echo "✓ Prompt integration installed to $PROFILE_D/nubiferos-prompt.sh"
else
    echo ""
    echo "Note: Not running as root. To install terminal prompt integration, run:"
    echo "  sudo cp $SCRIPT_DIR/nubiferos-prompt.sh $PROFILE_D/"
    echo "  sudo chmod +x $PROFILE_D/nubiferos-prompt.sh"
fi

echo ""
echo "✓ Installation complete!"
echo ""
echo "Next steps:"
echo "  1. Restart GNOME Shell: Press Alt+F2, type 'r', press Enter"
echo "     (Or log out and log back in)"
echo "  2. The context indicator should appear in the top bar"
echo "  3. Create a workspace: nubifer-workspace create --name 'AWS Prod' --provider aws --account-id 123"
echo "  4. Switch to it: nubifer-workspace switch <workspace-id>"
echo "  5. The indicator will update automatically"
echo ""
echo "Terminal prompt integration:"
echo "  - Open a new terminal to see the workspace context in your prompt"
echo "  - Format: [☁️ WorkspaceName] user@host:path$"
echo ""
echo "Troubleshooting:"
echo "  - If extension doesn't appear, check: gnome-extensions list"
echo "  - View logs: journalctl -f -o cat /usr/bin/gnome-shell"
echo "  - Disable extension: gnome-extensions disable $EXTENSION_UUID"
echo ""
