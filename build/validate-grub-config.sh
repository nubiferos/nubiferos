#!/bin/bash
# Validate GRUB embedded config hasn't been broken
# This script checks that the CRITICAL GRUB configuration is still correct

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_ISO="${SCRIPT_DIR}/build-iso.sh"

echo "=========================================="
echo "GRUB Configuration Validator"
echo "=========================================="
echo ""

# Check if build-iso.sh exists
if [ ! -f "$BUILD_ISO" ]; then
    echo "❌ ERROR: build-iso.sh not found at $BUILD_ISO"
    exit 1
fi

echo "Checking GRUB embedded config..."
echo ""

# Check for the CRITICAL working pattern
if grep -q "set root=(cd)" "$BUILD_ISO" && \
   grep -q "configfile (cd)/boot/grub/grub.cfg" "$BUILD_ISO" && \
   grep -q "set root=(cd0)" "$BUILD_ISO" && \
   grep -q "configfile (cd0)/boot/grub/grub.cfg" "$BUILD_ISO"; then
    echo "✅ PASS: Sequential device tries found"
else
    echo "❌ FAIL: Sequential device tries NOT found"
    echo ""
    echo "The GRUB embedded config has been modified!"
    echo "See: docs/fixes/GRUB_EMBEDDED_CONFIG_CRITICAL.md"
    exit 1
fi

# Check for BROKEN patterns that don't work
# Exclude comments when checking
if grep -v '^[[:space:]]*#' "$BUILD_ISO" | grep -q 'if \[ -e (cd)'; then
    echo "❌ FAIL: Conditional logic found (BROKEN)"
    echo ""
    echo "Conditionals don't work in GRUB embedded config!"
    echo "See: docs/fixes/GRUB_EMBEDDED_CONFIG_CRITICAL.md"
    exit 1
else
    echo "✅ PASS: No broken conditionals"
fi

# Check for relative path usage
if grep -q '"boot/grub/grub.cfg=boot/grub/embedded.cfg"' "$BUILD_ISO"; then
    echo "✅ PASS: Relative path used for embedded.cfg"
else
    echo "❌ FAIL: Relative path NOT used"
    echo ""
    echo "Must use: boot/grub/grub.cfg=boot/grub/embedded.cfg"
    echo "See: docs/fixes/GRUB_EMBEDDED_CONFIG_CRITICAL.md"
    exit 1
fi

# Check that embedded.cfg is created in ISO directory
if grep -q 'cat > "${ISO_DIR}/boot/grub/embedded.cfg"' "$BUILD_ISO"; then
    echo "✅ PASS: embedded.cfg created in ISO directory"
else
    echo "❌ FAIL: embedded.cfg NOT in ISO directory"
    echo ""
    echo "Must create embedded.cfg in \${ISO_DIR}/boot/grub/"
    echo "See: docs/fixes/GRUB_EMBEDDED_CONFIG_CRITICAL.md"
    exit 1
fi

# Check for WORK_DIR usage (BROKEN)
if grep -q 'grub-early.cfg' "$BUILD_ISO" || grep -q '${WORK_DIR}/.*\.cfg' "$BUILD_ISO"; then
    echo "❌ FAIL: Config file in WORK_DIR (BROKEN)"
    echo ""
    echo "Config must be in ISO_DIR, not WORK_DIR"
    echo "See: docs/fixes/GRUB_EMBEDDED_CONFIG_CRITICAL.md"
    exit 1
else
    echo "✅ PASS: No WORK_DIR config files"
fi

echo ""
echo "=========================================="
echo "✅ ALL CHECKS PASSED"
echo "=========================================="
echo ""
echo "GRUB embedded config is correct."
echo "The ISO should boot without manual intervention."
echo ""
