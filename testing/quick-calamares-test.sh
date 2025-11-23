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

# Test 2: Can we launch it?
echo ""
echo "Launching Calamares installer..."
echo "(You may be prompted for password)"
echo ""

pkexec calamares &

echo ""
echo "Calamares should now be launching..."
echo "If it doesn't appear, check for errors above."
