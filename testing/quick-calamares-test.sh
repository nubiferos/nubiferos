#!/bin/bash
# Quick Calamares test - run this in your live environment

echo "=== Quick Calamares Test ==="
echo ""

# Test 1: Is it installed?
if command -v calamares &> /dev/null; then
    echo "✓ Calamares is installed"
else
    echo "✗ Calamares NOT installed - run: sudo apt install calamares"
    exit 1
fi

# Test 2: Prepare environment
echo ""
echo "Preparing environment..."

# Ensure XDG_RUNTIME_DIR exists for root
sudo mkdir -p /run/user/0
sudo chmod 700 /run/user/0

# Test 3: Launch it
echo ""
echo "Launching Calamares installer..."
echo "(You may be prompted for password)"
echo ""

# Create wrapper script with proper environment
WRAPPER=$(mktemp)
cat > "$WRAPPER" << 'EOFWRAPPER'
#!/bin/bash
export DISPLAY="${DISPLAY:-:0}"
export XDG_RUNTIME_DIR="/run/user/0"
export QT_X11_NO_MITSHM=1
exec /usr/bin/calamares "$@"
EOFWRAPPER

chmod +x "$WRAPPER"

# Launch with pkexec
pkexec "$WRAPPER" &

# Clean up after a moment
sleep 2
rm -f "$WRAPPER"

echo ""
echo "Calamares should now be launching..."
echo "If it doesn't appear, check for errors above."
