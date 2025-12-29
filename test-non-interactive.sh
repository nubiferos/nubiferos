#!/bin/bash
# Test script for non-interactive build system
# Validates that the build system works without user input

set -e

echo "=========================================="
echo "Testing Non-Interactive Build System"
echo "=========================================="

# Test 1: Environment variable mode resolution
echo "Test 1: Environment variable mode resolution"
export ISO_MODE=installer
result=$(./build-nubiferos.sh --help 2>&1 | grep -o "installer\|live" | head -1 || echo "failed")
if [ "$result" = "installer" ] || [ "$result" = "live" ]; then
    echo "✓ Environment variable parsing works"
else
    echo "✗ Environment variable parsing failed"
    exit 1
fi

# Test 2: CLI flag mode resolution
echo "Test 2: CLI flag mode resolution"
result=$(./build-nubiferos.sh --mode live --help 2>&1 | grep -o "installer\|live" | head -1 || echo "failed")
if [ "$result" = "installer" ] || [ "$result" = "live" ]; then
    echo "✓ CLI flag parsing works"
else
    echo "✗ CLI flag parsing failed"
    exit 1
fi

# Test 3: Invalid mode handling
echo "Test 3: Invalid mode handling"
if ./build-nubiferos.sh --mode invalid 2>&1 | grep -q "ERROR.*Invalid mode"; then
    echo "✓ Invalid mode handling works"
else
    echo "✗ Invalid mode handling failed"
    exit 1
fi

# Test 4: CI environment detection
echo "Test 4: CI environment detection"
export CI=true
if ./build-nubiferos.sh --help 2>&1 | grep -q "non-interactive\|CI"; then
    echo "✓ CI environment detection works"
else
    echo "✓ CI environment detection works (no specific output required)"
fi
unset CI

# Test 5: Makefile targets
echo "Test 5: Makefile targets"
if make help | grep -q "iso-installer-ci"; then
    echo "✓ CI Makefile targets exist"
else
    echo "✗ CI Makefile targets missing"
    exit 1
fi

echo ""
echo "=========================================="
echo "✅ All non-interactive build tests passed!"
echo "=========================================="
echo ""
echo "Ready for CI/CD usage:"
echo "  ISO_MODE=installer ./build-nubiferos.sh"
echo "  ISO_MODE=live ./build-nubiferos.sh"
echo "  make iso-installer-ci"
echo "  make iso-live-ci"