#!/bin/bash
# Test script for NubiferOS Context Manager systemd service

set -e

echo "=== NubiferOS Context Manager Service Test ==="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((TESTS_PASSED++))
}

fail() {
    echo -e "${RED}✗${NC} $1"
    ((TESTS_FAILED++))
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Check if service files exist
echo "1. Checking service files..."
if [ -f "nubifer-context-manager.service" ]; then
    pass "Service file exists"
else
    fail "Service file not found"
fi

if [ -f "org.nubiferos.ContextManager.service" ]; then
    pass "D-Bus service file exists"
else
    fail "D-Bus service file not found"
fi

echo ""

# Check if service is installed
echo "2. Checking service installation..."
if [ -f "$HOME/.config/systemd/user/nubifer-context-manager.service" ]; then
    pass "Service installed in user systemd"
else
    warn "Service not installed (run install.sh first)"
fi

if [ -f "$HOME/.local/share/dbus-1/services/org.nubiferos.ContextManager.service" ]; then
    pass "D-Bus service file installed"
else
    warn "D-Bus service file not installed (run install.sh first)"
fi

echo ""

# Check if service is running
echo "3. Checking service status..."
if systemctl --user is-active --quiet nubifer-context-manager.service 2>/dev/null; then
    pass "Service is running"
    
    # Show service status
    echo ""
    echo "Service status:"
    systemctl --user status nubifer-context-manager.service --no-pager | head -n 10
else
    warn "Service is not running"
    echo "   To start: systemctl --user start nubifer-context-manager.service"
fi

echo ""

# Check if D-Bus service is accessible
echo "4. Testing D-Bus interface..."
if command -v dbus-send &> /dev/null; then
    if dbus-send --session --print-reply \
        --dest=org.freedesktop.DBus \
        /org/freedesktop/DBus \
        org.freedesktop.DBus.ListNames 2>/dev/null | grep -q "org.nubiferos.ContextManager"; then
        pass "D-Bus service is registered"
        
        # Try to call a method
        echo ""
        echo "Testing D-Bus method call (ListWorkspaces)..."
        if dbus-send --session --print-reply \
            --dest=org.nubiferos.ContextManager \
            /org/nubiferos/ContextManager \
            org.nubiferos.ContextManager.ListWorkspaces \
            string:"" 2>/dev/null >/dev/null; then
            pass "D-Bus method call successful"
        else
            fail "D-Bus method call failed"
        fi
    else
        warn "D-Bus service not registered (service may not be running)"
    fi
else
    warn "dbus-send not available, skipping D-Bus tests"
fi

echo ""

# Check if CLI is working
echo "5. Testing CLI integration..."
if command -v nubifer-workspace &> /dev/null; then
    pass "CLI command available"
    
    # Try to list workspaces
    echo ""
    echo "Testing CLI (list workspaces)..."
    if nubifer-workspace list &>/dev/null; then
        pass "CLI list command works"
    else
        fail "CLI list command failed"
    fi
else
    warn "CLI not installed (run install.sh first)"
fi

echo ""

# Check logs
echo "6. Checking service logs..."
if systemctl --user is-active --quiet nubifer-context-manager.service 2>/dev/null; then
    echo ""
    echo "Recent service logs:"
    journalctl --user -u nubifer-context-manager.service -n 5 --no-pager 2>/dev/null || warn "Could not read logs"
else
    warn "Service not running, no logs to check"
fi

echo ""
echo "=== Test Summary ==="
echo -e "Passed: ${GREEN}${TESTS_PASSED}${NC}"
echo -e "Failed: ${RED}${TESTS_FAILED}${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    echo ""
    echo "Common fixes:"
    echo "  - Install the service: cd .. && sudo ./install.sh"
    echo "  - Start the service: systemctl --user start nubifer-context-manager.service"
    echo "  - Check logs: journalctl --user -u nubifer-context-manager.service -f"
    exit 1
fi
