#!/bin/bash
# Verify NubiferOS Workspace Manager installation

echo "Verifying NubiferOS Workspace Manager installation..."
echo "======================================================"
echo ""

ERRORS=0

# Check commands
echo "Checking commands..."
if command -v nubifer-workspace &> /dev/null; then
    echo "✓ nubifer-workspace command found"
else
    echo "✗ nubifer-workspace command not found"
    ERRORS=$((ERRORS + 1))
fi

# Check directories
echo ""
echo "Checking directories..."

DIRS=(
    "/etc/nubifer"
    "/usr/local/lib/nubifer"
)

for dir in "${DIRS[@]}"; do
    if [ -d "$dir" ]; then
        echo "✓ $dir exists"
    else
        echo "✗ $dir missing"
        ERRORS=$((ERRORS + 1))
    fi
done

# Check files
echo ""
echo "Checking files..."

FILES=(
    "/usr/local/bin/nubifer-workspace"
    "/etc/nubifer/shell-integration.sh"
)

for file in "${FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "✓ $file exists"
    else
        echo "✗ $file missing"
        ERRORS=$((ERRORS + 1))
    fi
done

# Check Firejail integration (optional)
echo ""
echo "Checking Firejail integration (optional)..."

if command -v firejail &> /dev/null; then
    echo "✓ Firejail installed"
    
    if [ -d "/etc/firejail/nubifer" ]; then
        echo "✓ Firejail profiles directory exists"
        
        PROFILES=(
            "/etc/firejail/nubifer/nubifer-base.profile"
            "/etc/firejail/nubifer/nubifer-aws.profile"
            "/etc/firejail/nubifer/nubifer-azure.profile"
            "/etc/firejail/nubifer/nubifer-gcp.profile"
            "/etc/firejail/nubifer/nubifer-oracle.profile"
        )
        
        for profile in "${PROFILES[@]}"; do
            if [ -f "$profile" ]; then
                echo "  ✓ $(basename $profile)"
            else
                echo "  ✗ $(basename $profile) missing"
            fi
        done
    else
        echo "⚠ Firejail profiles directory not found (run install-firejail.sh)"
    fi
    
    if [ -d "/usr/local/lib/nubifer/cli-wrappers" ]; then
        echo "✓ CLI wrappers directory exists"
        
        WRAPPERS=(
            "/usr/local/lib/nubifer/cli-wrappers/aws"
            "/usr/local/lib/nubifer/cli-wrappers/az"
            "/usr/local/lib/nubifer/cli-wrappers/gcloud"
            "/usr/local/lib/nubifer/cli-wrappers/oci"
        )
        
        for wrapper in "${WRAPPERS[@]}"; do
            if [ -f "$wrapper" ]; then
                echo "  ✓ $(basename $wrapper)"
            else
                echo "  ✗ $(basename $wrapper) missing"
            fi
        done
    else
        echo "⚠ CLI wrappers directory not found (run install-firejail.sh)"
    fi
else
    echo "⚠ Firejail not installed (optional)"
fi

# Check shell integration
echo ""
echo "Checking shell integration..."

if grep -q "nubifer/shell-integration.sh" /etc/bash.bashrc 2>/dev/null; then
    echo "✓ Shell integration added to /etc/bash.bashrc"
else
    echo "⚠ Shell integration not in /etc/bash.bashrc (may need to source manually)"
fi

# Summary
echo ""
echo "======================================================"
if [ $ERRORS -eq 0 ]; then
    echo "✓ Installation verified successfully!"
    echo ""
    echo "Next steps:"
    echo "  1. Restart your shell: exec bash"
    echo "  2. Create a workspace: nubifer-workspace create --name 'Test' --provider aws --account-id 123"
    echo "  3. List workspaces: nubifer-workspace list"
else
    echo "✗ Installation has $ERRORS error(s)"
    echo ""
    echo "To fix:"
    echo "  sudo ./install.sh"
    echo "  sudo ./install-firejail.sh  # Optional, for Firejail integration"
fi
echo "======================================================"
