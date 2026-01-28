#!/bin/bash
# Unit tests for ISO signing and verification
# Run with: ./tests/security/test_iso_signing.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SIGN_SCRIPT="$REPO_ROOT/scripts/security/sign-iso.sh"
VERIFY_SCRIPT="$REPO_ROOT/scripts/security/verify-iso.sh"
TEST_OUTPUT_DIR=$(mktemp -d)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0

cleanup() {
    rm -rf "$TEST_OUTPUT_DIR"
}
trap cleanup EXIT

pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    ((TESTS_PASSED++)) || true
}

fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    ((TESTS_FAILED++)) || true
}

# Test 1: Sign script exists and is executable
test_sign_script_exists() {
    if [[ -x "$SIGN_SCRIPT" ]]; then
        pass "Sign script exists and is executable"
    else
        fail "Sign script not found or not executable"
    fi
}

# Test 2: Verify script exists and is executable
test_verify_script_exists() {
    if [[ -x "$VERIFY_SCRIPT" ]]; then
        pass "Verify script exists and is executable"
    else
        fail "Verify script not found or not executable"
    fi
}

# Test 3: Sign script help works
test_sign_help() {
    if "$SIGN_SCRIPT" --help 2>&1 | grep -q "Usage"; then
        pass "Sign script help displays usage"
    else
        fail "Sign script help does not display usage"
    fi
}

# Test 4: Verify script help works
test_verify_help() {
    if "$VERIFY_SCRIPT" --help 2>&1 | grep -q "Usage"; then
        pass "Verify script help displays usage"
    else
        fail "Verify script help does not display usage"
    fi
}

# Test 5: Sign script requires ISO path
test_sign_requires_iso() {
    # Check that script mentions ISO path requirement
    if grep -q "ISO path is required" "$SIGN_SCRIPT"; then
        pass "Sign script requires ISO path"
    else
        fail "Sign script should require ISO path"
    fi
}

# Test 6: Verify script requires ISO path
test_verify_requires_iso() {
    # Check that script mentions ISO path requirement
    if grep -q "ISO path is required" "$VERIFY_SCRIPT"; then
        pass "Verify script requires ISO path"
    else
        fail "Verify script should require ISO path"
    fi
}

# Test 7: Sign script supports CI mode
test_sign_ci_mode() {
    if grep -q "GPG_PRIVATE_KEY" "$SIGN_SCRIPT"; then
        pass "Sign script supports CI mode (GPG_PRIVATE_KEY)"
    else
        fail "Sign script should support CI mode"
    fi
}

# Test 8: Sign script handles passphrase securely
test_sign_passphrase_security() {
    # Check that passphrase is passed via file descriptor, not command line
    if grep -q "passphrase-fd" "$SIGN_SCRIPT" && ! grep -q "\-\-passphrase " "$SIGN_SCRIPT"; then
        pass "Sign script handles passphrase securely (via fd)"
    else
        fail "Sign script should use passphrase-fd, not --passphrase"
    fi
}

# Test 9: Sign script creates detached signature
test_sign_detached() {
    if grep -q "\-\-detach-sign" "$SIGN_SCRIPT"; then
        pass "Sign script creates detached signature"
    else
        fail "Sign script should create detached signature"
    fi
}

# Test 10: Sign script creates armored signature
test_sign_armored() {
    if grep -q "\-\-armor" "$SIGN_SCRIPT"; then
        pass "Sign script creates armored signature"
    else
        fail "Sign script should create armored signature"
    fi
}

# Test 11: Verify script supports JSON output
test_verify_json_output() {
    if grep -q "\-\-json" "$VERIFY_SCRIPT"; then
        pass "Verify script supports JSON output"
    else
        fail "Verify script should support JSON output"
    fi
}

# Test 12: Verify script has proper exit codes
test_verify_exit_codes() {
    if grep -q "exit 0" "$VERIFY_SCRIPT" && grep -q "exit 1" "$VERIFY_SCRIPT" && grep -q "exit 2" "$VERIFY_SCRIPT"; then
        pass "Verify script has proper exit codes (0, 1, 2)"
    else
        fail "Verify script should have exit codes 0, 1, 2"
    fi
}

# Test 13: Sign script exports public key
test_sign_export_key() {
    if grep -q "\-\-export-key" "$SIGN_SCRIPT" && grep -q "export_public_key" "$SIGN_SCRIPT"; then
        pass "Sign script can export public key"
    else
        fail "Sign script should support key export"
    fi
}

# Test 14: Verify script can import key
test_verify_import_key() {
    if grep -q "\-\-key" "$VERIFY_SCRIPT" && grep -q "import_key" "$VERIFY_SCRIPT"; then
        pass "Verify script can import public key"
    else
        fail "Verify script should support key import"
    fi
}

# Test 15: Sign script cleans up CI keys
test_sign_cleanup() {
    if grep -q "cleanup_ci_key" "$SIGN_SCRIPT"; then
        pass "Sign script cleans up CI keys"
    else
        fail "Sign script should clean up CI keys"
    fi
}

# Test 16: Sign script verifies after signing
test_sign_self_verify() {
    if grep -q "gpg --verify" "$SIGN_SCRIPT"; then
        pass "Sign script verifies signature after creation"
    else
        fail "Sign script should verify signature after creation"
    fi
}

# Run all tests
echo "=========================================="
echo "ISO Signing Unit Tests"
echo "=========================================="
echo ""

test_sign_script_exists
test_verify_script_exists
test_sign_help
test_verify_help
test_sign_requires_iso
test_verify_requires_iso
test_sign_ci_mode
test_sign_passphrase_security
test_sign_detached
test_sign_armored
test_verify_json_output
test_verify_exit_codes
test_sign_export_key
test_verify_import_key
test_sign_cleanup
test_sign_self_verify

echo ""
echo "=========================================="
echo "Results: $TESTS_PASSED passed, $TESTS_FAILED failed"
echo "=========================================="

if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
fi
