#!/bin/bash
# NubiferOS CLI Installation Script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing NubiferOS CLI..."

# Check for Python 3.9+
PYTHON_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
REQUIRED_VERSION="3.9"

if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$PYTHON_VERSION" | sort -V | head -n1)" != "$REQUIRED_VERSION" ]; then
    echo "✗ Python $REQUIRED_VERSION or higher is required (found $PYTHON_VERSION)"
    exit 1
fi

# Check for pip
if ! command -v pip3 &> /dev/null; then
    echo "✗ pip3 is required but not installed"
    echo "  Install with: sudo apt install python3-pip"
    exit 1
fi

# Install mode selection
if [ "$1" == "--user" ]; then
    echo "Installing for current user..."
    pip3 install --user "$SCRIPT_DIR"
    echo "✓ Installed to ~/.local/bin/nubifer"
    echo "  Make sure ~/.local/bin is in your PATH"
elif [ "$1" == "--dev" ]; then
    echo "Installing in development mode..."
    pip3 install -e "$SCRIPT_DIR[dev]"
    echo "✓ Installed in editable mode"
elif [ "$EUID" -eq 0 ]; then
    echo "Installing system-wide..."
    pip3 install "$SCRIPT_DIR"
    echo "✓ Installed to /usr/local/bin/nubifer"
else
    echo "Installing for current user (use sudo for system-wide)..."
    pip3 install --user "$SCRIPT_DIR"
    echo "✓ Installed to ~/.local/bin/nubifer"
    echo "  Make sure ~/.local/bin is in your PATH"
fi

# Verify installation
if command -v nubifer &> /dev/null; then
    echo ""
    nubifer --version
    echo ""
    echo "Run 'nubifer --help' to get started"
else
    echo ""
    echo "Installation complete. You may need to restart your shell or add the install location to PATH."
fi
