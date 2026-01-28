#!/bin/bash
# Unit tests for vulnerability scanning
# Run with: ./tests/security/test_vuln_scan.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VULN_SCRIPT="$REPO_ROOT/scripts/security/vuln-scan.sh"
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

# Test 1: Script exists and is executable
test_script_exists() {
    if [[ -x "$VULN_SCRIPT" ]]; then
        pass "Vuln scan script exists and is executable"
    else
        fail "Vuln scan script not found or not executable"
    fi
}

# Test 2: Help flag works
test_help_flag() {
    if "$VULN_SCRIPT" --help 2>&1 | grep -q "Usage"; then
        pass "Help flag displays usage"
    else
        fail "Help flag does not display usage"
    fi
}

# Test 3: Threshold options documented
test_threshold_options() {
    if "$VULN_SCRIPT" --help 2>&1 | grep -q "critical.*high.*medium.*low"; then
        pass "Threshold options documented"
    else
        fail "Threshold options not documented"
    fi
}

# Test 4: SBOM input supported
test_sbom_input() {
    if grep -q "\-\-sbom" "$VULN_SCRIPT"; then
        pass "SBOM input parameter supported"
    else
        fail "SBOM input not supported"
    fi
}

# Test 5: Directory input supported
test_dir_input() {
    if grep -q "\-\-dir" "$VULN_SCRIPT"; then
        pass "Directory input parameter supported"
    else
        fail "Directory input not supported"
    fi
}

# Test 6: Allowlist support
test_allowlist_support() {
    if grep -q "allowlist" "$VULN_SCRIPT" && grep -q "load_allowlist" "$VULN_SCRIPT"; then
        pass "Allowlist support implemented"
    else
        fail "Allowlist support not found"
    fi
}

# Test 7: JSON output generation
test_json_output() {
    if grep -q "\.vulns\.json" "$VULN_SCRIPT"; then
        pass "JSON output generation implemented"
    else
        fail "JSON output not implemented"
    fi
}

# Test 8: Human-readable report generation
test_report_generation() {
    if grep -q "generate_report" "$VULN_SCRIPT"; then
        pass "Human-readable report generation implemented"
    else
        fail "Report generation not found"
    fi
}

# Test 9: Severity counting
test_severity_counting() {
    if grep -q "count_by_severity" "$VULN_SCRIPT"; then
        pass "Severity counting implemented"
    else
        fail "Severity counting not found"
    fi
}

# Test 10: Threshold checking
test_threshold_checking() {
    if grep -q "check_threshold" "$VULN_SCRIPT"; then
        pass "Threshold checking implemented"
    else
        fail "Threshold checking not found"
    fi
}

# Test 11: Grype installation
test_grype_installation() {
    if grep -q "install_grype" "$VULN_SCRIPT"; then
        pass "Grype auto-installation implemented"
    else
        fail "Grype installation not found"
    fi
}

# Test 12: Exit codes documented
test_exit_codes() {
    if grep -q "Exit codes" "$VULN_SCRIPT" || grep -q "exit 0\|exit 1\|exit 2" "$VULN_SCRIPT"; then
        pass "Exit codes implemented"
    else
        fail "Exit codes not documented"
    fi
}

# Test 13: Allowlist file exists
test_allowlist_file() {
    if [[ -f "$REPO_ROOT/security/vuln-allowlist.yaml" ]]; then
        pass "Allowlist template file exists"
    else
        fail "Allowlist template file not found"
    fi
}

# Test 14: Allowlist YAML is valid
test_allowlist_yaml() {
    local allowlist="$REPO_ROOT/security/vuln-allowlist.yaml"
    if grep -q "vulnerabilities:" "$allowlist"; then
        pass "Allowlist YAML has correct structure"
    else
        fail "Allowlist YAML structure invalid"
    fi
}

# Run all tests
echo "=========================================="
echo "Vulnerability Scanner Unit Tests"
echo "=========================================="
echo ""

test_script_exists
test_help_flag
test_threshold_options
test_sbom_input
test_dir_input
test_allowlist_support
test_json_output
test_report_generation
test_severity_counting
test_threshold_checking
test_grype_installation
test_exit_codes
test_allowlist_file
test_allowlist_yaml

echo ""
echo "=========================================="
echo "Results: $TESTS_PASSED passed, $TESTS_FAILED failed"
echo "=========================================="

if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
fi
