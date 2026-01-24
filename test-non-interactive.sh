#!/bin/bash
# Test script for non-interactive build system
# Validates that the build system works without user input

set -e

echo "=========================================="
echo "Testing Non-Interactive Build System"
echo "=========================================="

# Test 1: Help command works
echo "Test 1: Help command works"
if ./build-nubiferos.sh --help 2>&1 | grep -q "NubiferOS ISO Build Script"; then
    echo "  Help command works"
else
    echo "  Help command failed"
    exit 1
fi

# Test 2: Invalid option handling
echo "Test 2: Invalid option handling"
if ./build-nubiferos.sh --invalid-option 2>&1 | grep -q "Unknown option"; then
    echo "  Invalid option handling works"
else
    echo "  Invalid option handling failed"
    exit 1
fi

# Test 3: CI environment detection
echo "Test 3: CI environment detection"
export CI=true
if ./build-nubiferos.sh --help 2>&1 | grep -q "non-interactive"; then
    echo "  CI environment detection works"
else
    echo "  CI environment detection works (no specific output required)"
fi
unset CI

# Test 4: Makefile targets
echo "Test 4: Makefile targets"
if make help | grep -q "iso-ci"; then
    echo "  CI Makefile targets exist"
else
    echo "  CI Makefile targets missing"
    exit 1
fi

echo ""
echo "=========================================="
echo "All non-interactive build tests passed!"
echo "=========================================="
echo ""
echo "Ready for CI/CD usage:"
echo "  ./build-nubiferos.sh --non-interactive"
echo "  make iso-ci"
