#!/bin/bash
# Unit tests for compliance checking
# Run with: ./tests/security/test_compliance_check.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
COMPLIANCE_SCRIPT="$REPO_ROOT/scripts/security/compliance-check.sh"
BASELINE_FILE="$REPO_ROOT/security/compliance-baseline.yaml"
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
    if [[ -x "$COMPLIANCE_SCRIPT" ]]; then
        pass "Compliance script exists and is executable"
    else
        fail "Compliance script not found or not executable"
    fi
}

# Test 2: Help flag works
test_help_flag() {
    if "$COMPLIANCE_SCRIPT" --help 2>&1 | grep -q "Usage"; then
        pass "Help flag displays usage"
    else
        fail "Help flag does not display usage"
    fi
}

# Test 3: Chroot mode supported
test_chroot_mode() {
    if grep -q "\-\-chroot" "$COMPLIANCE_SCRIPT"; then
        pass "Chroot mode supported"
    else
        fail "Chroot mode not supported"
    fi
}

# Test 4: Live mode supported
test_live_mode() {
    if grep -q "\-\-live" "$COMPLIANCE_SCRIPT"; then
        pass "Live mode supported"
    else
        fail "Live mode not supported"
    fi
}

# Test 5: Min score configurable
test_min_score() {
    if grep -q "\-\-min-score" "$COMPLIANCE_SCRIPT"; then
        pass "Minimum score is configurable"
    else
        fail "Minimum score not configurable"
    fi
}

# Test 6: Baseline file exists
test_baseline_exists() {
    if [[ -f "$BASELINE_FILE" ]]; then
        pass "Baseline configuration file exists"
    else
        fail "Baseline configuration file not found"
    fi
}

# Test 7: Baseline has min_score
test_baseline_min_score() {
    if grep -q "min_score:" "$BASELINE_FILE"; then
        pass "Baseline has min_score configuration"
    else
        fail "Baseline missing min_score"
    fi
}

# Test 8: Baseline has required_checks
test_baseline_required_checks() {
    if grep -q "required_checks:" "$BASELINE_FILE"; then
        pass "Baseline has required_checks list"
    else
        fail "Baseline missing required_checks"
    fi
}

# Test 9: JSON output supported
test_json_output() {
    if grep -q "\-\-json" "$COMPLIANCE_SCRIPT"; then
        pass "JSON output supported"
    else
        fail "JSON output not supported"
    fi
}

# Test 10: Lynis installation function
test_lynis_install() {
    if grep -q "install_lynis" "$COMPLIANCE_SCRIPT"; then
        pass "Lynis auto-installation implemented"
    else
        fail "Lynis installation not found"
    fi
}

# Test 11: Score parsing function
test_score_parsing() {
    if grep -q "parse_hardening_index" "$COMPLIANCE_SCRIPT"; then
        pass "Hardening index parsing implemented"
    else
        fail "Score parsing not found"
    fi
}

# Test 12: Exit codes documented
test_exit_codes() {
    if grep -q "Exit codes" "$COMPLIANCE_SCRIPT"; then
        pass "Exit codes documented"
    else
        fail "Exit codes not documented"
    fi
}

# Test 13: Report generation
test_report_generation() {
    if grep -q "parse_findings\|generate_json_report" "$COMPLIANCE_SCRIPT"; then
        pass "Report generation implemented"
    else
        fail "Report generation not found"
    fi
}

# Test 14: Baseline loading
test_baseline_loading() {
    if grep -q "load_baseline" "$COMPLIANCE_SCRIPT"; then
        pass "Baseline loading implemented"
    else
        fail "Baseline loading not found"
    fi
}

# Test 15: Output directory support
test_output_dir() {
    if grep -q "\-\-output" "$COMPLIANCE_SCRIPT"; then
        pass "Output directory configurable"
    else
        fail "Output directory not configurable"
    fi
}

# Run all tests
echo "=========================================="
echo "Compliance Check Unit Tests"
echo "=========================================="
echo ""

test_script_exists
test_help_flag
test_chroot_mode
test_live_mode
test_min_score
test_baseline_exists
test_baseline_min_score
test_baseline_required_checks
test_json_output
test_lynis_install
test_score_parsing
test_exit_codes
test_report_generation
test_baseline_loading
test_output_dir

echo ""
echo "=========================================="
echo "Results: $TESTS_PASSED passed, $TESTS_FAILED failed"
echo "=========================================="

if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
fi
