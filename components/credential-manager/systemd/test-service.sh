#!/bin/bash
# Test script to verify systemd service configuration

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Testing NubiferOS Credential Manager systemd service configuration..."
echo ""

# Check if systemd-analyze is available
if ! command -v systemd-analyze &> /dev/null; then
    echo "⚠️  systemd-analyze not found, skipping validation"
    echo "   Install systemd for full validation"
    exit 0
fi

# Validate service file syntax
echo "1. Validating service file syntax..."
if systemd-analyze verify "$SCRIPT_DIR/nubifer-credential-manager.service" 2>&1 | grep -q "Failed"; then
    echo "❌ Service file validation failed"
    systemd-analyze verify "$SCRIPT_DIR/nubifer-credential-manager.service"
    exit 1
else
    echo "✓ Service file syntax is valid"
fi

# Check required files exist
echo ""
echo "2. Checking required files..."

if [ ! -f "$SCRIPT_DIR/nubifer-credential-manager.service" ]; then
    echo "❌ Missing: nubifer-credential-manager.service"
    exit 1
fi
echo "✓ nubifer-credential-manager.service exists"

if [ ! -f "$SCRIPT_DIR/org.nubiferos.CredentialManager.service" ]; then
    echo "❌ Missing: org.nubiferos.CredentialManager.service"
    exit 1
fi
echo "✓ org.nubiferos.CredentialManager.service exists"

if [ ! -f "$SCRIPT_DIR/README.md" ]; then
    echo "❌ Missing: README.md"
    exit 1
fi
echo "✓ README.md exists"

# Check service file content
echo ""
echo "3. Checking service file content..."

if ! grep -q "Type=dbus" "$SCRIPT_DIR/nubifer-credential-manager.service"; then
    echo "❌ Service type should be 'dbus'"
    exit 1
fi
echo "✓ Service type is 'dbus'"

if ! grep -q "BusName=org.nubiferos.CredentialManager" "$SCRIPT_DIR/nubifer-credential-manager.service"; then
    echo "❌ BusName not set correctly"
    exit 1
fi
echo "✓ BusName is set correctly"

if ! grep -q "ExecStart=/usr/local/bin/nubifer-creds-service" "$SCRIPT_DIR/nubifer-credential-manager.service"; then
    echo "❌ ExecStart path incorrect"
    exit 1
fi
echo "✓ ExecStart path is correct"

# Check D-Bus service file content
echo ""
echo "4. Checking D-Bus service file content..."

if ! grep -q "Name=org.nubiferos.CredentialManager" "$SCRIPT_DIR/org.nubiferos.CredentialManager.service"; then
    echo "❌ D-Bus service name not set correctly"
    exit 1
fi
echo "✓ D-Bus service name is correct"

if ! grep -q "SystemdService=nubifer-credential-manager.service" "$SCRIPT_DIR/org.nubiferos.CredentialManager.service"; then
    echo "❌ SystemdService reference incorrect"
    exit 1
fi
echo "✓ SystemdService reference is correct"

# Check security hardening
echo ""
echo "5. Checking security hardening..."

if ! grep -q "NoNewPrivileges=true" "$SCRIPT_DIR/nubifer-credential-manager.service"; then
    echo "⚠️  NoNewPrivileges not enabled"
else
    echo "✓ NoNewPrivileges enabled"
fi

if ! grep -q "PrivateTmp=true" "$SCRIPT_DIR/nubifer-credential-manager.service"; then
    echo "⚠️  PrivateTmp not enabled"
else
    echo "✓ PrivateTmp enabled"
fi

if ! grep -q "ProtectSystem=strict" "$SCRIPT_DIR/nubifer-credential-manager.service"; then
    echo "⚠️  ProtectSystem not set to strict"
else
    echo "✓ ProtectSystem set to strict"
fi

if ! grep -q "ProtectHome=read-only" "$SCRIPT_DIR/nubifer-credential-manager.service"; then
    echo "⚠️  ProtectHome not set to read-only"
else
    echo "✓ ProtectHome set to read-only"
fi

# Check restart policy
echo ""
echo "6. Checking restart policy..."

if ! grep -q "Restart=on-failure" "$SCRIPT_DIR/nubifer-credential-manager.service"; then
    echo "⚠️  Restart policy not set"
else
    echo "✓ Restart policy configured"
fi

echo ""
echo "✅ All checks passed!"
echo ""
echo "Service configuration is valid and ready for installation."
echo ""
echo "To install and enable:"
echo "  cd components/credential-manager"
echo "  sudo ./install.sh"
echo "  systemctl --user enable nubifer-credential-manager.service"
echo ""
