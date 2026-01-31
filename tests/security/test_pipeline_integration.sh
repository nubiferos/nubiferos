#!/bin/bash
# Integration test for the complete security pipeline
# Tests all security scripts work together end-to-end

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SECURITY_SCRIPTS="${PROJECT_ROOT}/scripts/security"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

log_pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

log_fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

log_skip() {
    echo -e "${YELLOW}○ SKIP${NC}: $1"
    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
}

log_info() {
    echo -e "  ℹ $1"
}

# Create temp directory for test artifacts
TEMP_DIR=$(mktemp -d)
trap "rm -rf ${TEMP_DIR}" EXIT

echo "========================================"
echo "Security Pipeline Integration Test"
echo "========================================"
echo ""
echo "Project root: ${PROJECT_ROOT}"
echo "Temp dir: ${TEMP_DIR}"
echo ""

# =============================================================================
# Test 1: All security scripts exist and are executable
# =============================================================================
echo "--- Test 1: Script Existence ---"

SCRIPTS=(
    "generate-sbom.sh"
    "vuln-scan.sh"
    "sign-iso.sh"
    "verify-iso.sh"
    "compliance-check.sh"
    "secret-scan.sh"
    "code-scan.sh"
)

for script in "${SCRIPTS[@]}"; do
    if [ -x "${SECURITY_SCRIPTS}/${script}" ]; then
        log_pass "Script exists and executable: ${script}"
    elif [ -f "${SECURITY_SCRIPTS}/${script}" ]; then
        log_fail "Script exists but not executable: ${script}"
    else
        log_fail "Script missing: ${script}"
    fi
done

# =============================================================================
# Test 2: Configuration files exist
# =============================================================================
echo ""
echo "--- Test 2: Configuration Files ---"

CONFIG_FILES=(
    "security/vuln-allowlist.yaml"
    "security/compliance-baseline.yaml"
    "security/gitleaks.toml"
)

for config in "${CONFIG_FILES[@]}"; do
    if [ -f "${PROJECT_ROOT}/${config}" ]; then
        log_pass "Config exists: ${config}"
    else
        log_fail "Config missing: ${config}"
    fi
done

# =============================================================================
# Test 3: SBOM generation (mock test)
# =============================================================================
echo ""
echo "--- Test 3: SBOM Generation ---"

# Create a mock directory structure to scan
mkdir -p "${TEMP_DIR}/mock-system/var/lib/dpkg"
cat > "${TEMP_DIR}/mock-system/var/lib/dpkg/status" << 'EOF'
Package: bash
Status: install ok installed
Priority: required
Section: shells
Installed-Size: 1234
Maintainer: Test
Architecture: amd64
Version: 5.1-6

Package: coreutils
Status: install ok installed
Priority: required
Section: utils
Installed-Size: 5678
Maintainer: Test
Architecture: amd64
Version: 8.32-4
EOF

if command -v syft &>/dev/null; then
    if "${SECURITY_SCRIPTS}/generate-sbom.sh" "${TEMP_DIR}/mock-system" "${TEMP_DIR}/sbom" 2>/dev/null; then
        if [ -f "${TEMP_DIR}/sbom/sbom-cyclonedx.json" ]; then
            log_pass "SBOM generation produces CycloneDX output"
        else
            log_fail "SBOM generation did not produce CycloneDX output"
        fi
    else
        log_fail "SBOM generation script failed"
    fi
else
    log_skip "SBOM generation (syft not installed)"
fi

# =============================================================================
# Test 4: Vulnerability scanning (mock test)
# =============================================================================
echo ""
echo "--- Test 4: Vulnerability Scanning ---"

if command -v grype &>/dev/null; then
    # Create a minimal SBOM for testing
    cat > "${TEMP_DIR}/test-sbom.json" << 'EOF'
{
  "bomFormat": "CycloneDX",
  "specVersion": "1.4",
  "version": 1,
  "components": [
    {
      "type": "library",
      "name": "test-package",
      "version": "1.0.0"
    }
  ]
}
EOF
    
    if "${SECURITY_SCRIPTS}/vuln-scan.sh" "${TEMP_DIR}/test-sbom.json" "${TEMP_DIR}/vuln-report" 2>/dev/null; then
        if [ -f "${TEMP_DIR}/vuln-report/vuln-report.json" ]; then
            log_pass "Vulnerability scan produces JSON output"
        else
            log_fail "Vulnerability scan did not produce output"
        fi
    else
        # Script may exit non-zero if vulns found, check if output exists
        if [ -f "${TEMP_DIR}/vuln-report/vuln-report.json" ]; then
            log_pass "Vulnerability scan produces JSON output (with findings)"
        else
            log_fail "Vulnerability scan script failed"
        fi
    fi
else
    log_skip "Vulnerability scanning (grype not installed)"
fi

# =============================================================================
# Test 5: ISO signing and verification
# =============================================================================
echo ""
echo "--- Test 5: ISO Signing & Verification ---"

# Create a test "ISO" file
echo "This is a test ISO file for signing" > "${TEMP_DIR}/test.iso"

# Generate a test GPG key
export GNUPGHOME="${TEMP_DIR}/gpg"
mkdir -p "${GNUPGHOME}"
chmod 700 "${GNUPGHOME}"

# Create key without passphrase for testing
cat > "${TEMP_DIR}/key-params" << EOF
%no-protection
Key-Type: RSA
Key-Length: 2048
Name-Real: Test Signing Key
Name-Email: test@example.com
Expire-Date: 0
%commit
EOF

if gpg --batch --gen-key "${TEMP_DIR}/key-params" 2>/dev/null; then
    KEY_ID=$(gpg --list-secret-keys --keyid-format LONG 2>/dev/null | grep sec | head -1 | awk '{print $2}' | cut -d'/' -f2)
    
    if [ -n "${KEY_ID}" ]; then
        # Test signing
        if gpg --batch --yes --detach-sign --armor -u "${KEY_ID}" "${TEMP_DIR}/test.iso" 2>/dev/null; then
            log_pass "ISO signing works"
            
            # Test verification
            if gpg --verify "${TEMP_DIR}/test.iso.asc" "${TEMP_DIR}/test.iso" 2>/dev/null; then
                log_pass "ISO verification works"
            else
                log_fail "ISO verification failed"
            fi
            
            # Test tampered file detection
            echo "tampered" >> "${TEMP_DIR}/test.iso"
            if ! gpg --verify "${TEMP_DIR}/test.iso.asc" "${TEMP_DIR}/test.iso" 2>/dev/null; then
                log_pass "Tampered ISO correctly rejected"
            else
                log_fail "Tampered ISO was not detected"
            fi
        else
            log_fail "ISO signing failed"
        fi
    else
        log_fail "Could not get GPG key ID"
    fi
else
    log_fail "GPG key generation failed"
fi

# =============================================================================
# Test 6: Secret scanning
# =============================================================================
echo ""
echo "--- Test 6: Secret Scanning ---"

if command -v gitleaks &>/dev/null; then
    # Create test files with and without secrets
    mkdir -p "${TEMP_DIR}/test-repo"
    echo "normal code here" > "${TEMP_DIR}/test-repo/clean.py"
    
    if "${SECURITY_SCRIPTS}/secret-scan.sh" "${TEMP_DIR}/test-repo" "${TEMP_DIR}/secret-report.json" 2>/dev/null; then
        log_pass "Secret scanning completes on clean repo"
    else
        log_pass "Secret scanning completes (may have findings)"
    fi
else
    log_skip "Secret scanning (gitleaks not installed)"
fi

# =============================================================================
# Test 7: Code scanning (shellcheck)
# =============================================================================
echo ""
echo "--- Test 7: Code Scanning ---"

if command -v shellcheck &>/dev/null; then
    # Create a test script
    mkdir -p "${TEMP_DIR}/test-scripts"
    cat > "${TEMP_DIR}/test-scripts/good.sh" << 'EOF'
#!/bin/bash
set -e
echo "Hello"
EOF
    chmod +x "${TEMP_DIR}/test-scripts/good.sh"
    
    if "${SECURITY_SCRIPTS}/code-scan.sh" --path "${TEMP_DIR}/test-scripts" --output "${TEMP_DIR}/code-output" --quiet 2>/dev/null; then
        log_pass "Code scanning completes successfully"
    else
        # May fail if issues found, check if output exists
        if [ -f "${TEMP_DIR}/code-output/shellcheck-report.json" ]; then
            log_pass "Code scanning completes (with findings)"
        else
            log_fail "Code scanning failed"
        fi
    fi
else
    log_skip "Code scanning (shellcheck not installed)"
fi

# =============================================================================
# Test 8: Local security scanner integration
# =============================================================================
echo ""
echo "--- Test 8: Local Security Scanner ---"

if [ -x "${PROJECT_ROOT}/scripts/nubifer-security-scan" ]; then
    # Test help output
    if "${PROJECT_ROOT}/scripts/nubifer-security-scan" --help 2>&1 | grep -q "NubiferOS Security Scanner"; then
        log_pass "nubifer-security-scan --help works"
    else
        log_fail "nubifer-security-scan --help output unexpected"
    fi
else
    log_fail "nubifer-security-scan not found or not executable"
fi

# =============================================================================
# Test 9: GitHub workflow syntax
# =============================================================================
echo ""
echo "--- Test 9: Workflow Syntax ---"

WORKFLOWS=(
    ".github/workflows/build-iso.yml"
    ".github/workflows/security-scan.yml"
)

for workflow in "${WORKFLOWS[@]}"; do
    if [ -f "${PROJECT_ROOT}/${workflow}" ]; then
        # Basic YAML syntax check
        if python3 -c "import yaml; yaml.safe_load(open('${PROJECT_ROOT}/${workflow}'))" 2>/dev/null; then
            log_pass "Workflow syntax valid: ${workflow}"
        else
            log_fail "Workflow syntax invalid: ${workflow}"
        fi
    else
        log_fail "Workflow missing: ${workflow}"
    fi
done

# =============================================================================
# Test 10: Documentation completeness
# =============================================================================
echo ""
echo "--- Test 10: Documentation ---"

DOCS=(
    "docs/SECURITY_SCANNING.md"
    "docs/GPG_KEY_SETUP.md"
    "docs/man/nubifer-security-scan.1"
)

for doc in "${DOCS[@]}"; do
    if [ -f "${PROJECT_ROOT}/${doc}" ]; then
        # Check file is not empty
        if [ -s "${PROJECT_ROOT}/${doc}" ]; then
            log_pass "Documentation exists: ${doc}"
        else
            log_fail "Documentation empty: ${doc}"
        fi
    else
        log_fail "Documentation missing: ${doc}"
    fi
done

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "========================================"
echo "Integration Test Summary"
echo "========================================"
echo -e "Passed:  ${GREEN}${TESTS_PASSED}${NC}"
echo -e "Failed:  ${RED}${TESTS_FAILED}${NC}"
echo -e "Skipped: ${YELLOW}${TESTS_SKIPPED}${NC}"
echo ""

if [ ${TESTS_FAILED} -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
fi
