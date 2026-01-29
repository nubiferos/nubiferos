#!/bin/bash
# Unit tests for secret and code scanning
# Run with: ./tests/security/test_secret_code_scan.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SECRET_SCRIPT="$REPO_ROOT/scripts/security/secret-scan.sh"
CODE_SCRIPT="$REPO_ROOT/scripts/security/code-scan.sh"
GITLEAKS_CONFIG="$REPO_ROOT/security/gitleaks.toml"
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

# ==========================================
# Secret Scanner Tests
# ==========================================

test_secret_script_exists() {
    if [[ -x "$SECRET_SCRIPT" ]]; then
        pass "Secret scan script exists and is executable"
    else
        fail "Secret scan script not found or not executable"
    fi
}

test_secret_help() {
    if "$SECRET_SCRIPT" --help 2>&1 | grep -q "Usage"; then
        pass "Secret scan help displays usage"
    else
        fail "Secret scan help does not display usage"
    fi
}

test_secret_gitleaks_install() {
    if grep -q "install_gitleaks" "$SECRET_SCRIPT"; then
        pass "Gitleaks auto-installation implemented"
    else
        fail "Gitleaks installation not found"
    fi
}

test_secret_config_support() {
    if grep -q "\-\-config" "$SECRET_SCRIPT"; then
        pass "Custom config support implemented"
    else
        fail "Custom config not supported"
    fi
}

test_secret_baseline_support() {
    if grep -q "\-\-baseline" "$SECRET_SCRIPT"; then
        pass "Baseline support implemented"
    else
        fail "Baseline not supported"
    fi
}

test_secret_json_output() {
    if grep -q "json" "$SECRET_SCRIPT" && grep -q "sarif" "$SECRET_SCRIPT"; then
        pass "JSON and SARIF output supported"
    else
        fail "JSON/SARIF output not supported"
    fi
}

test_gitleaks_config_exists() {
    if [[ -f "$GITLEAKS_CONFIG" ]]; then
        pass "Gitleaks config file exists"
    else
        fail "Gitleaks config file not found"
    fi
}

test_gitleaks_config_nubifer_rules() {
    if grep -q "nubifer-credential-path" "$GITLEAKS_CONFIG"; then
        pass "NubiferOS-specific rules in gitleaks config"
    else
        fail "NubiferOS rules not found in config"
    fi
}

test_gitleaks_config_aws_export() {
    if grep -q "aws-credential-export" "$GITLEAKS_CONFIG"; then
        pass "AWS export detection rule present"
    else
        fail "AWS export rule not found"
    fi
}

test_gitleaks_config_allowlist() {
    if grep -q "\[allowlist\]" "$GITLEAKS_CONFIG"; then
        pass "Allowlist section in gitleaks config"
    else
        fail "Allowlist not found in config"
    fi
}

# ==========================================
# Code Scanner Tests
# ==========================================

test_code_script_exists() {
    if [[ -x "$CODE_SCRIPT" ]]; then
        pass "Code scan script exists and is executable"
    else
        fail "Code scan script not found or not executable"
    fi
}

test_code_help() {
    if "$CODE_SCRIPT" --help 2>&1 | grep -q "Usage"; then
        pass "Code scan help displays usage"
    else
        fail "Code scan help does not display usage"
    fi
}

test_code_shellcheck_install() {
    if grep -q "install_shellcheck" "$CODE_SCRIPT"; then
        pass "Shellcheck auto-installation implemented"
    else
        fail "Shellcheck installation not found"
    fi
}

test_code_severity_levels() {
    if grep -q "error.*warning.*info.*style" "$CODE_SCRIPT"; then
        pass "Severity levels supported"
    else
        fail "Severity levels not supported"
    fi
}

test_code_json_output() {
    if grep -q "\-\-json" "$CODE_SCRIPT"; then
        pass "JSON output supported"
    else
        fail "JSON output not supported"
    fi
}

test_code_exclude_support() {
    if grep -q "\-\-exclude" "$CODE_SCRIPT"; then
        pass "Code exclusion supported"
    else
        fail "Code exclusion not supported"
    fi
}

test_code_find_scripts() {
    if grep -q "find_scripts" "$CODE_SCRIPT"; then
        pass "Script discovery implemented"
    else
        fail "Script discovery not found"
    fi
}

test_code_shebang_detection() {
    if grep -q "shebang\|#!" "$CODE_SCRIPT"; then
        pass "Shebang detection for extensionless scripts"
    else
        fail "Shebang detection not found"
    fi
}

# Run all tests
echo "=========================================="
echo "Secret and Code Scanner Unit Tests"
echo "=========================================="
echo ""
echo "--- Secret Scanner ---"
test_secret_script_exists
test_secret_help
test_secret_gitleaks_install
test_secret_config_support
test_secret_baseline_support
test_secret_json_output
test_gitleaks_config_exists
test_gitleaks_config_nubifer_rules
test_gitleaks_config_aws_export
test_gitleaks_config_allowlist

echo ""
echo "--- Code Scanner ---"
test_code_script_exists
test_code_help
test_code_shellcheck_install
test_code_severity_levels
test_code_json_output
test_code_exclude_support
test_code_find_scripts
test_code_shebang_detection

echo ""
echo "=========================================="
echo "Results: $TESTS_PASSED passed, $TESTS_FAILED failed"
echo "=========================================="

if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
fi
