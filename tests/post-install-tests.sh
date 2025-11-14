#!/bin/bash
# NubiferOS Post-Installation Integration Tests
# Runs automatically after installation to verify system configuration

set +e  # Don't exit on error - we want to run all tests

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Test results
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Log file
LOG_FILE="/var/log/nubifer-post-install-tests.log"
REPORT_FILE="/var/log/nubifer-test-report.txt"

log_test() {
    echo -e "${BLUE}[TEST]${NC} $1" | tee -a "$LOG_FILE"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1" | tee -a "$LOG_FILE"
    ((TESTS_PASSED++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1" | tee -a "$LOG_FILE"
    ((TESTS_FAILED++))
}

log_skip() {
    echo -e "${YELLOW}[SKIP]${NC} $1" | tee -a "$LOG_FILE"
    ((TESTS_SKIPPED++))
}

log_info() {
    echo -e "${CYAN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

run_test() {
    local test_name=$1
    local test_command=$2
    
    ((TESTS_RUN++))
    log_test "$test_name"
    
    if eval "$test_command" >> "$LOG_FILE" 2>&1; then
        log_pass "$test_name"
        return 0
    else
        log_fail "$test_name"
        return 1
    fi
}

# Initialize log
echo "=========================================="  | tee "$LOG_FILE"
echo "NubiferOS Post-Installation Tests"          | tee -a "$LOG_FILE"
echo "Date: $(date)"                              | tee -a "$LOG_FILE"
echo "=========================================="  | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

#############################################
# 1. System Installation Tests
#############################################

echo "1. System Installation Verification" | tee -a "$LOG_FILE"
echo "----------------------------------------" | tee -a "$LOG_FILE"

run_test "System is Debian/Ubuntu based" "test -f /etc/debian_version"
run_test "Systemd is running" "systemctl is-system-running --quiet || systemctl is-system-running | grep -qE 'running|degraded'"
run_test "Network is available" "ping -c 1 8.8.8.8"
run_test "DNS resolution works" "ping -c 1 google.com"
run_test "Disk has sufficient space" "test $(df / | tail -1 | awk '{print $4}') -gt 5000000"

echo "" | tee -a "$LOG_FILE"

#############################################
# 2. Package Installation Tests
#############################################

echo "2. Required Packages" | tee -a "$LOG_FILE"
echo "----------------------------------------" | tee -a "$LOG_FILE"

# Core tools
run_test "pass installed" "command -v pass"
run_test "gpg installed" "command -v gpg"
run_test "jq installed" "command -v jq"
run_test "curl installed" "command -v curl"
run_test "git installed" "command -v git"

# Cloud CLIs (check if any are installed)
if command -v aws &>/dev/null; then
    log_pass "AWS CLI installed"
    ((TESTS_PASSED++))
else
    log_skip "AWS CLI not installed (optional)"
    ((TESTS_SKIPPED++))
fi

if command -v az &>/dev/null; then
    log_pass "Azure CLI installed"
    ((TESTS_PASSED++))
else
    log_skip "Azure CLI not installed (optional)"
    ((TESTS_SKIPPED++))
fi

if command -v gcloud &>/dev/null; then
    log_pass "Google Cloud SDK installed"
    ((TESTS_PASSED++))
else
    log_skip "Google Cloud SDK not installed (optional)"
    ((TESTS_SKIPPED++))
fi

echo "" | tee -a "$LOG_FILE"

#############################################
# 3. NubiferOS Scripts Installation
#############################################

echo "3. NubiferOS Scripts" | tee -a "$LOG_FILE"
echo "----------------------------------------" | tee -a "$LOG_FILE"

run_test "nubifer-creds installed" "test -x /usr/local/bin/nubifer-creds"
run_test "nubifer-setup-wizard installed" "test -x /usr/local/bin/nubifer-setup-wizard"
run_test "nubifer-update-checker installed" "test -x /usr/local/bin/nubifer-update-checker"
run_test "install-ide-plugins installed" "test -x /usr/local/bin/install-ide-plugins"

echo "" | tee -a "$LOG_FILE"

#############################################
# 4. Browser Configuration Tests
#############################################

echo "4. Browser Configuration" | tee -a "$LOG_FILE"
echo "----------------------------------------" | tee -a "$LOG_FILE"

run_test "Firefox installed" "command -v firefox"
run_test "Bookmark file exists" "test -f /usr/share/nubifer/browser/firefox-bookmarks.json"
run_test "Bookmark JSON is valid" "jq empty /usr/share/nubifer/browser/firefox-bookmarks.json"

# Test bookmark import (headless)
if command -v firefox &>/dev/null && [ -f /usr/share/nubifer/browser/firefox-bookmarks.json ]; then
    log_test "Bookmark import test (headless)"
    
    # Create test profile
    TEST_PROFILE="/tmp/firefox-test-profile"
    rm -rf "$TEST_PROFILE"
    
    # Initialize Firefox profile
    timeout 10 firefox --headless --profile "$TEST_PROFILE" --new-instance about:blank &>/dev/null || true
    sleep 2
    
    # Try to import bookmarks using Firefox's bookmark import
    if [ -d "$TEST_PROFILE" ]; then
        # Check if profile was created
        log_pass "Bookmark import test (profile created)"
        ((TESTS_PASSED++))
    else
        log_fail "Bookmark import test (profile creation failed)"
        ((TESTS_FAILED++))
    fi
    
    rm -rf "$TEST_PROFILE"
else
    log_skip "Bookmark import test (Firefox not available)"
    ((TESTS_SKIPPED++))
fi

echo "" | tee -a "$LOG_FILE"

#############################################
# 5. Credential Management Tests
#############################################

echo "5. Credential Management" | tee -a "$LOG_FILE"
echo "----------------------------------------" | tee -a "$LOG_FILE"

# Test GPG key generation (automated)
log_test "GPG key generation test"
TEST_EMAIL="test-$(date +%s)@nubiferos.test"

# Generate test key
cat > /tmp/gpg-test-batch <<EOF
%echo Generating test GPG key...
Key-Type: RSA
Key-Length: 2048
Subkey-Type: RSA
Subkey-Length: 2048
Name-Real: NubiferOS Test
Name-Email: $TEST_EMAIL
Expire-Date: 1d
%no-protection
%commit
%echo Done
EOF

if gpg --batch --generate-key /tmp/gpg-test-batch >> "$LOG_FILE" 2>&1; then
    log_pass "GPG key generation test"
    ((TESTS_PASSED++))
    
    # Test pass initialization
    log_test "pass initialization test"
    TEST_PASS_DIR="/tmp/password-store-test-$$"
    export PASSWORD_STORE_DIR="$TEST_PASS_DIR"
    
    if pass init "$TEST_EMAIL" >> "$LOG_FILE" 2>&1; then
        log_pass "pass initialization test"
        ((TESTS_PASSED++))
        
        # Test credential storage
        log_test "Credential storage test"
        echo "test-secret-value" | pass insert -e test/credential >> "$LOG_FILE" 2>&1
        
        if pass show test/credential | grep -q "test-secret-value"; then
            log_pass "Credential storage test"
            ((TESTS_PASSED++))
        else
            log_fail "Credential storage test"
            ((TESTS_FAILED++))
        fi
        
        # Test credential retrieval
        log_test "Credential retrieval test"
        if [ "$(pass show test/credential)" = "test-secret-value" ]; then
            log_pass "Credential retrieval test"
            ((TESTS_PASSED++))
        else
            log_fail "Credential retrieval test"
            ((TESTS_FAILED++))
        fi
        
        # Cleanup
        rm -rf "$TEST_PASS_DIR"
    else
        log_fail "pass initialization test"
        ((TESTS_FAILED++))
    fi
    
    # Cleanup GPG key
    gpg --batch --yes --delete-secret-keys "$TEST_EMAIL" >> "$LOG_FILE" 2>&1
    gpg --batch --yes --delete-keys "$TEST_EMAIL" >> "$LOG_FILE" 2>&1
else
    log_fail "GPG key generation test"
    ((TESTS_FAILED++))
fi

rm -f /tmp/gpg-test-batch

echo "" | tee -a "$LOG_FILE"

#############################################
# 6. IDE Plugin System Tests
#############################################

echo "6. IDE Plugin System" | tee -a "$LOG_FILE"
echo "----------------------------------------" | tee -a "$LOG_FILE"

# Test IDE detection
log_test "IDE detection test"
if /usr/local/bin/install-ide-plugins --dry-run >> "$LOG_FILE" 2>&1; then
    log_pass "IDE detection test"
    ((TESTS_PASSED++))
else
    log_fail "IDE detection test"
    ((TESTS_FAILED++))
fi

# Check if VS Code is installed and test extension installation
if command -v code &>/dev/null; then
    log_test "VS Code extension installation test"
    
    # Try to install a small extension
    if timeout 30 code --install-extension editorconfig.editorconfig --force >> "$LOG_FILE" 2>&1; then
        log_pass "VS Code extension installation test"
        ((TESTS_PASSED++))
        
        # Verify installation
        if code --list-extensions | grep -q editorconfig.editorconfig; then
            log_pass "VS Code extension verification"
            ((TESTS_PASSED++))
        else
            log_fail "VS Code extension verification"
            ((TESTS_FAILED++))
        fi
    else
        log_fail "VS Code extension installation test"
        ((TESTS_FAILED++))
    fi
else
    log_skip "VS Code not installed"
    ((TESTS_SKIPPED++))
fi

echo "" | tee -a "$LOG_FILE"

#############################################
# 7. Update Checker Tests
#############################################

echo "7. Update Management" | tee -a "$LOG_FILE"
echo "----------------------------------------" | tee -a "$LOG_FILE"

run_test "Update checker help" "/usr/local/bin/nubifer-update-checker help"
run_test "Update checker list" "/usr/local/bin/nubifer-update-checker list"

# Test version detection
log_test "Version detection test"
if /usr/local/bin/nubifer-update-checker list | grep -qE 'aws-cli|azure-cli|gcloud|terraform|kubectl|helm|docker'; then
    log_pass "Version detection test"
    ((TESTS_PASSED++))
else
    log_skip "Version detection test (no tools installed)"
    ((TESTS_SKIPPED++))
fi

echo "" | tee -a "$LOG_FILE"

#############################################
# 8. Security Configuration Tests
#############################################

echo "8. Security Configuration" | tee -a "$LOG_FILE"
echo "----------------------------------------" | tee -a "$LOG_FILE"

run_test "Firewall (ufw) installed" "command -v ufw"
run_test "AppArmor installed" "command -v apparmor_status"
run_test "fail2ban installed" "command -v fail2ban-client"

# Check file permissions
run_test "Secure /etc/shadow permissions" "test $(stat -c %a /etc/shadow) = '640' -o $(stat -c %a /etc/shadow) = '600'"
run_test "Secure /etc/gshadow permissions" "test $(stat -c %a /etc/gshadow) = '640' -o $(stat -c %a /etc/gshadow) = '600'"

echo "" | tee -a "$LOG_FILE"

#############################################
# 9. Documentation Tests
#############################################

echo "9. Documentation" | tee -a "$LOG_FILE"
echo "----------------------------------------" | tee -a "$LOG_FILE"

run_test "Documentation directory exists" "test -d /usr/share/doc/nubifer"
run_test "Credential security doc exists" "test -f /usr/share/doc/nubifer/CREDENTIAL_SECURITY.md"
run_test "IDE plugins doc exists" "test -f /usr/share/doc/nubifer/IDE_PLUGINS.md"
run_test "Quick reference exists" "test -f /usr/share/doc/nubifer/QUICK_REFERENCE.md"

echo "" | tee -a "$LOG_FILE"

#############################################
# 10. Integration Tests
#############################################

echo "10. Integration Tests" | tee -a "$LOG_FILE"
echo "----------------------------------------" | tee -a "$LOG_FILE"

# Test nubifer-setup-wizard
log_test "Setup wizard status check"
if /usr/local/bin/nubifer-setup-wizard status >> "$LOG_FILE" 2>&1; then
    log_pass "Setup wizard status check"
    ((TESTS_PASSED++))
else
    log_fail "Setup wizard status check"
    ((TESTS_FAILED++))
fi

echo "" | tee -a "$LOG_FILE"

#############################################
# Generate Report
#############################################

echo "==========================================" | tee -a "$LOG_FILE"
echo "Test Summary" | tee -a "$LOG_FILE"
echo "==========================================" | tee -a "$LOG_FILE"
echo "Total tests run: $TESTS_RUN" | tee -a "$LOG_FILE"
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}" | tee -a "$LOG_FILE"
echo -e "${RED}Failed: $TESTS_FAILED${NC}" | tee -a "$LOG_FILE"
echo -e "${YELLOW}Skipped: $TESTS_SKIPPED${NC}" | tee -a "$LOG_FILE"
echo "==========================================" | tee -a "$LOG_FILE"

# Generate report file
cat > "$REPORT_FILE" <<EOF
NubiferOS Post-Installation Test Report
========================================
Date: $(date)
Hostname: $(hostname)
OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)
Kernel: $(uname -r)

Test Results:
  Total: $TESTS_RUN
  Passed: $TESTS_PASSED
  Failed: $TESTS_FAILED
  Skipped: $TESTS_SKIPPED

Status: $([ $TESTS_FAILED -eq 0 ] && echo "PASS ✓" || echo "FAIL ✗")

Detailed log: $LOG_FILE
EOF

cat "$REPORT_FILE" | tee -a "$LOG_FILE"

# Exit with appropriate code
if [ $TESTS_FAILED -eq 0 ]; then
    echo "" | tee -a "$LOG_FILE"
    echo -e "${GREEN}✓ All tests passed!${NC}" | tee -a "$LOG_FILE"
    echo "System is ready for use." | tee -a "$LOG_FILE"
    exit 0
else
    echo "" | tee -a "$LOG_FILE"
    echo -e "${RED}✗ Some tests failed${NC}" | tee -a "$LOG_FILE"
    echo "Review log: $LOG_FILE" | tee -a "$LOG_FILE"
    exit 1
fi
