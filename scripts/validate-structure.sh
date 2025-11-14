#!/bin/bash
# CloudOS Project Structure Validation Script

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${PROJECT_ROOT}"

echo "Validating CloudOS project structure..."
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Validation counters
PASSED=0
FAILED=0

# Function to check if directory exists
check_dir() {
    if [ -d "$1" ]; then
        echo -e "${GREEN}✓${NC} Directory exists: $1"
        ((PASSED++))
    else
        echo -e "${RED}✗${NC} Directory missing: $1"
        ((FAILED++))
    fi
}

# Function to check if file exists
check_file() {
    if [ -f "$1" ]; then
        echo -e "${GREEN}✓${NC} File exists: $1"
        ((PASSED++))
    else
        echo -e "${RED}✗${NC} File missing: $1"
        ((FAILED++))
    fi
}

echo "=== Checking Root Files ==="
check_file "README.md"
check_file "LICENSE"
check_file "CONTRIBUTING.md"
check_file "CHANGELOG.md"
check_file ".gitignore"
check_file "VERSION"
echo ""

echo "=== Checking Build System ==="
check_dir "build"
check_file "build/config.sh"
check_file "build/README.md"
echo ""

echo "=== Checking Components ==="
check_dir "components"
check_file "components/README.md"

check_dir "components/credential-manager"
check_dir "components/credential-manager/src"
check_dir "components/credential-manager/config"
check_dir "components/credential-manager/systemd"

check_dir "components/context-manager"
check_dir "components/context-manager/src"
check_dir "components/context-manager/dbus"
check_dir "components/context-manager/systemd"

check_dir "components/resource-viewer"
check_dir "components/resource-viewer/src"
check_dir "components/resource-viewer/backend"
check_dir "components/resource-viewer/indexer"
check_dir "components/resource-viewer/database"

check_dir "components/context-indicator"
check_dir "components/context-indicator/gnome-extension"
check_dir "components/context-indicator/kde-plasmoid"
echo ""

echo "=== Checking Configuration Directories ==="
check_dir "configs"
check_dir "configs/desktop"
check_dir "configs/cloud-tools"
check_dir "configs/security"
echo ""

echo "=== Checking Installer ==="
check_dir "installer"
check_dir "installer/calamares"
check_dir "installer/scripts"
echo ""

echo "=== Checking Documentation ==="
check_dir "docs"
check_file "docs/README.md"
echo ""

echo "=== Checking Build Workspace ==="
check_dir "iso"
echo ""

echo "=== Checking Specifications ==="
check_dir ".kiro/specs/custom-linux-distro"
check_file ".kiro/specs/custom-linux-distro/requirements.md"
check_file ".kiro/specs/custom-linux-distro/design.md"
check_file ".kiro/specs/custom-linux-distro/tasks.md"
echo ""

echo "=== Testing Build Configuration ==="
if source build/config.sh && validate_config > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Build configuration is valid"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} Build configuration validation failed"
    ((FAILED++))
fi
echo ""

echo "=========================================="
echo "Validation Results:"
echo -e "${GREEN}Passed: ${PASSED}${NC}"
if [ ${FAILED} -gt 0 ]; then
    echo -e "${RED}Failed: ${FAILED}${NC}"
    echo ""
    echo "Some checks failed. Please review the output above."
    exit 1
else
    echo -e "${GREEN}All checks passed!${NC}"
    echo ""
    echo "CloudOS project structure is valid and ready for development."
    exit 0
fi
