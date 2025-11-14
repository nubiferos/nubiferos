#!/bin/bash
# Automated test runner for NubiferOS

# Don't exit on error - we want to run all tests
set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
}

log_skip() {
    echo -e "${YELLOW}[SKIP]${NC} $1"
    ((TESTS_SKIPPED++))
}

run_test() {
    local test_name=$1
    local test_command=$2
    
    ((TESTS_RUN++))
    log_test "$test_name"
    
    local output
    local exit_code
    
    output=$(eval "$test_command" 2>&1)
    exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        log_pass "$test_name"
        return 0
    else
        log_fail "$test_name"
        if [ -n "$output" ]; then
            echo "  Error: $output" | head -3
        fi
        return 1
    fi
}

echo "=========================================="
echo "NubiferOS Automated Test Suite"
echo "=========================================="
echo ""

cd "$PROJECT_ROOT"

# Test 1: Syntax Checks
echo "1. Syntax Checks"
echo "----------------------------------------"

if command -v shellcheck &> /dev/null; then
    run_test "IDE plugin script syntax" "shellcheck configs/ide/install-ide-plugins.sh"
    run_test "Update checker script syntax" "shellcheck scripts/nubifer-update-checker"
else
    log_skip "shellcheck not installed"
    ((TESTS_SKIPPED+=2))
fi

run_test "Credential manager Python syntax" "python3 -m py_compile components/credential-manager/nubifer-creds"

if command -v jq &> /dev/null; then
    run_test "Bookmark JSON syntax" "jq empty configs/browser/firefox-bookmarks.json"
else
    log_skip "jq not installed"
    ((TESTS_SKIPPED++))
fi

echo ""

# Test 2: File Existence
echo "2. File Existence Checks"
echo "----------------------------------------"

run_test "IDE plugin script exists" "test -f configs/ide/install-ide-plugins.sh"
run_test "Credential manager exists" "test -f components/credential-manager/nubifer-creds"
run_test "Bookmarks file exists" "test -f configs/browser/firefox-bookmarks.json"
run_test "Credential security doc exists" "test -f docs/CREDENTIAL_SECURITY.md"
run_test "IDE plugins doc exists" "test -f docs/IDE_PLUGINS.md"
run_test "Solutions comparison doc exists" "test -f docs/CREDENTIAL_SOLUTIONS_COMPARISON.md"
run_test "Quick reference doc exists" "test -f docs/QUICK_REFERENCE.md"
run_test "Update checker exists" "test -f scripts/nubifer-update-checker"

echo ""

# Test 3: File Permissions
echo "3. File Permissions"
echo "----------------------------------------"

run_test "IDE plugin script executable" "test -x configs/ide/install-ide-plugins.sh"
run_test "Credential manager executable" "test -x components/credential-manager/nubifer-creds"
run_test "Update checker executable" "test -x scripts/nubifer-update-checker"

echo ""

# Test 4: Dependencies
echo "4. Dependency Checks"
echo "----------------------------------------"

if command -v pass &> /dev/null; then
    log_pass "pass installed"
    ((TESTS_PASSED++))
else
    log_fail "pass not installed"
    ((TESTS_FAILED++))
fi

if command -v gpg &> /dev/null; then
    log_pass "gpg installed"
    ((TESTS_PASSED++))
else
    log_fail "gpg not installed"
    ((TESTS_FAILED++))
fi

if command -v jq &> /dev/null; then
    log_pass "jq installed"
    ((TESTS_PASSED++))
else
    log_skip "jq not installed (optional)"
    ((TESTS_SKIPPED++))
fi

if command -v curl &> /dev/null; then
    log_pass "curl installed"
    ((TESTS_PASSED++))
else
    log_fail "curl not installed"
    ((TESTS_FAILED++))
fi

echo ""

# Test 5: Documentation Structure
echo "5. Documentation Structure"
echo "----------------------------------------"

run_test "All docs have headers" "grep -q '^# ' docs/*.md"
run_test "Credential doc has sections" "grep -q '## ' docs/CREDENTIAL_SECURITY.md"
run_test "IDE doc has sections" "grep -q '## ' docs/IDE_PLUGINS.md"

echo ""

# Test 6: Bookmark Structure
echo "6. Bookmark Structure"
echo "----------------------------------------"

if command -v jq &> /dev/null; then
    run_test "Bookmarks have title" "jq -e '.title' configs/browser/firefox-bookmarks.json"
    run_test "Bookmarks have children" "jq -e '.children' configs/browser/firefox-bookmarks.json"
    run_test "AWS section exists" "jq -e '.children[] | select(.title==\"AWS\")' configs/browser/firefox-bookmarks.json"
    run_test "Azure section exists" "jq -e '.children[] | select(.title==\"Azure\")' configs/browser/firefox-bookmarks.json"
    run_test "GCP section exists" "jq -e '.children[] | select(.title==\"Google Cloud\")' configs/browser/firefox-bookmarks.json"
else
    log_skip "jq not installed"
    ((TESTS_SKIPPED+=5))
fi

echo ""

# Test 7: Script Functionality
echo "7. Script Functionality"
echo "----------------------------------------"

run_test "Update checker help works" "./scripts/nubifer-update-checker help"
run_test "Update checker list works" "./scripts/nubifer-update-checker list"

echo ""

# Test 8: Pass Integration (if initialized)
echo "8. Pass Integration"
echo "----------------------------------------"

if [ -d "$HOME/.password-store" ]; then
    log_pass "pass initialized"
    ((TESTS_PASSED++))
    
    run_test "pass can list" "pass ls"
else
    log_skip "pass not initialized (run: pass init <gpg-key-id>)"
    ((TESTS_SKIPPED+=2))
fi

echo ""

# Summary
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo "Total tests run: $TESTS_RUN"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo -e "${YELLOW}Skipped: $TESTS_SKIPPED${NC}"
echo "=========================================="

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Review failed tests above"
    echo "2. Install missing dependencies"
    echo "3. Fix any issues"
    echo "4. Run tests again"
    exit 1
fi
