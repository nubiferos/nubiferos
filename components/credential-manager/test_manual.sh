#!/bin/bash
# Manual test script for NubiferOS Credential Manager

set -e

echo "=========================================="
echo "NubiferOS Credential Manager - Manual Test"
echo "=========================================="
echo ""

# Check if installed
if ! command -v nubifer-creds &> /dev/null; then
    echo "Error: nubifer-creds not installed"
    echo "Run: sudo ./install.sh"
    exit 1
fi

# Check status
echo "1. Checking status..."
nubifer-creds status
echo ""

# Check if pass is initialized
if ! pass ls &> /dev/null; then
    echo "Pass store not initialized. Run: nubifer-creds init"
    exit 1
fi

# Test adding AWS credentials (with dummy data)
echo "2. Testing add command (AWS)..."
echo "   Note: This will prompt for credentials"
echo "   Use dummy values for testing: AKIATEST123 / secret123"
echo ""

read -p "Press Enter to continue or Ctrl+C to skip..."

nubifer-creds add \
    --provider aws \
    --account-id 123456789012 \
    --account-name "Test Account"

echo ""

# List credentials
echo "3. Listing credentials..."
nubifer-creds list
echo ""

# Show credential details
echo "4. Showing credential details..."
nubifer-creds show --provider aws --account-id 123456789012
echo ""

# Test credential retrieval
echo "5. Testing credential retrieval..."
nubifer-creds test --provider aws --account-id 123456789012
echo ""

# Verify in pass
echo "6. Verifying in pass store..."
echo "   Access Key ID:"
pass show nubiferos/credentials/aws/123456789012/access_key_id
echo ""
echo "   Secret Access Key:"
pass show nubiferos/credentials/aws/123456789012/secret_access_key
echo ""

# List in JSON format
echo "7. Listing in JSON format..."
nubifer-creds list --format json
echo ""

# Cleanup
echo "8. Cleanup (delete test credential)..."
nubifer-creds delete --provider aws --account-id 123456789012
echo ""

echo "=========================================="
echo "✓ All tests completed successfully!"
echo "=========================================="
