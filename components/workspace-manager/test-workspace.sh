#!/bin/bash
# Test script for NubiferOS Workspace Manager

set -e

echo "Testing NubiferOS Workspace Manager..."
echo "========================================"
echo ""

# Make nubifer-workspace executable
chmod +x nubifer-workspace

# Test 1: Create AWS workspace
echo "Test 1: Creating AWS workspace..."
./nubifer-workspace create \
  --name "Test AWS Prod" \
  --provider aws \
  --account-id 123456789012 \
  --account-name "test-prod" \
  --region us-east-1

echo ""

# Test 2: Create Azure workspace
echo "Test 2: Creating Azure workspace..."
./nubifer-workspace create \
  --name "Test Azure Dev" \
  --provider azure \
  --account-id "azure-sub-123" \
  --account-name "test-dev" \
  --region eastus

echo ""

# Test 3: Create GCP workspace (read-only)
echo "Test 3: Creating GCP workspace (read-only)..."
./nubifer-workspace create \
  --name "Test GCP Staging" \
  --provider gcp \
  --account-id "gcp-project-123" \
  --account-name "test-staging" \
  --region us-central1 \
  --read-only

echo ""

# Test 4: List workspaces
echo "Test 4: Listing all workspaces..."
./nubifer-workspace list

echo ""

# Test 5: List AWS workspaces only
echo "Test 5: Listing AWS workspaces..."
./nubifer-workspace list --provider aws

echo ""

# Test 6: Get workspace ID for switching
echo "Test 6: Getting workspace ID..."
WORKSPACE_ID=$(ls ~/.config/nubifer/workspaces/ | head -1 | sed 's/.json//')
echo "Found workspace ID: $WORKSPACE_ID"

echo ""

# Test 7: Switch workspace
echo "Test 7: Switching to workspace..."
./nubifer-workspace switch "$WORKSPACE_ID"

echo ""

# Test 8: Show current workspace
echo "Test 8: Showing current workspace..."
./nubifer-workspace current

echo ""

# Test 9: Export environment
echo "Test 9: Exporting environment variables..."
./nubifer-workspace env "$WORKSPACE_ID"

echo ""

# Test 10: Enable read-only mode
echo "Test 10: Enabling read-only mode..."
./nubifer-workspace readonly "$WORKSPACE_ID" --enable

echo ""

# Test 11: Disable read-only mode (requires root — same gate as 'rw')
echo "Test 11: Disabling read-only mode..."
sudo ./nubifer-workspace readonly "$WORKSPACE_ID" --disable

echo ""

# Test 12: Update workspace
echo "Test 12: Updating workspace..."
./nubifer-workspace update "$WORKSPACE_ID" \
  --name "Updated Test Workspace" \
  --region us-west-2

echo ""

# Test 13: Check audit log
echo "Test 13: Checking audit log..."
if [ -f ~/.config/nubifer/workspace-audit.log ]; then
    echo "Audit log entries:"
    tail -5 ~/.config/nubifer/workspace-audit.log
else
    echo "✗ Audit log not found"
fi

echo ""

# Test 14: Verify file permissions
echo "Test 14: Verifying file permissions..."
WORKSPACE_FILE=~/.config/nubifer/workspaces/${WORKSPACE_ID}.json
if [ -f "$WORKSPACE_FILE" ]; then
    PERMS=$(stat -c %a "$WORKSPACE_FILE")
    if [ "$PERMS" = "600" ]; then
        echo "✓ Workspace file permissions correct (600)"
    else
        echo "✗ Workspace file permissions incorrect: $PERMS (expected 600)"
    fi
fi

echo ""

# Test 15: Delete workspace (create a temp one first)
echo "Test 15: Testing workspace deletion..."
TEMP_WS=$(./nubifer-workspace create \
  --name "Temp Workspace" \
  --provider aws \
  --account-id 999999999999 \
  --account-name "temp" | grep "ID:" | awk '{print $2}')

./nubifer-workspace delete "$TEMP_WS"

echo ""
echo "========================================"
echo "✓ All tests completed successfully!"
echo "========================================"
echo ""
echo "Cleanup: To remove test workspaces, run:"
echo "  rm -rf ~/.config/nubifer/"
