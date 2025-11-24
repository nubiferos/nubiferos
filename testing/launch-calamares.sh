#!/bin/bash
# Proper Calamares launcher that handles environment variables correctly
# This script works around the XDG_RUNTIME_DIR and DISPLAY issues

set -e

echo "=========================================="
echo "Launching Calamares Installer"
echo "=========================================="
echo ""

# Check if Calamares is installed
if ! command -v calamares &> /dev/null; then
    echo "✗ Calamares is not installed"
    echo "  Install with: sudo apt install calamares"
    exit 1
fi

# Get current user info
CURRENT_USER=$(whoami)
CURRENT_UID=$(id -u)
CURRENT_GID=$(id -g)

# Detect display server
if [ -n "$WAYLAND_DISPLAY" ]; then
    echo "Detected: Wayland display server"
    DISPLAY_TYPE="wayland"
elif [ -n "$DISPLAY" ]; then
    echo "Detected: X11 display server"
    DISPLAY_TYPE="x11"
else
    echo "✗ No display server detected"
    echo "  Make sure you're running this in a graphical session"
    exit 1
fi

echo "User: $CURRENT_USER (UID: $CURRENT_UID)"
echo ""

# Method 1: Try with xhost (X11 only)
if [ "$DISPLAY_TYPE" = "x11" ]; then
    echo "Method 1: Using xhost to grant root access to X11..."
    
    # Temporarily allow root to access X server
    xhost +SI:localuser:root > /dev/null 2>&1 || true
    
    # Launch with sudo, preserving necessary environment
    sudo -E \
        DISPLAY="$DISPLAY" \
        XAUTHORITY="$XAUTHORITY" \
        QT_X11_NO_MITSHM=1 \
        calamares
    
    # Revoke root access
    xhost -SI:localuser:root > /dev/null 2>&1 || true
    
    exit 0
fi

# Method 2: For Wayland or if Method 1 fails
echo "Method 2: Using pkexec with environment preservation..."

# Create a temporary wrapper script
WRAPPER_SCRIPT=$(mktemp)
cat > "$WRAPPER_SCRIPT" << 'EOF'
#!/bin/bash
# Temporary wrapper for Calamares

# Set up environment - critical for Qt applications
export DISPLAY="${DISPLAY:-:0}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY}"

# Create XDG_RUNTIME_DIR for root if it doesn't exist
if [ ! -d "/run/user/0" ]; then
    mkdir -p /run/user/0
    chmod 700 /run/user/0
fi
export XDG_RUNTIME_DIR="/run/user/0"

# Qt platform configuration
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-xcb}"

# For Wayland
if [ -n "$WAYLAND_DISPLAY" ]; then
    export QT_QPA_PLATFORM="wayland"
fi

# Disable Qt's shared memory to avoid X11 issues
export QT_X11_NO_MITSHM=1

# Launch Calamares
exec /usr/bin/calamares "$@"
EOF

chmod +x "$WRAPPER_SCRIPT"

# Launch using pkexec
pkexec "$WRAPPER_SCRIPT"

# Clean up
rm -f "$WRAPPER_SCRIPT"

echo ""
echo "=========================================="
echo "Calamares should now be running"
echo "=========================================="
