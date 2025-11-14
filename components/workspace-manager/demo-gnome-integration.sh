#!/bin/bash
# Demo script for NubiferOS GNOME Virtual Desktop Integration

set -e

echo "=========================================="
echo "NubiferOS GNOME Virtual Desktop Demo"
echo "=========================================="
echo ""

# Check if running in GNOME
if [ "$XDG_CURRENT_DESKTOP" != "GNOME" ] && [ "$DESKTOP_SESSION" != "gnome" ]; then
    echo "⚠️  This demo requires GNOME desktop environment"
    echo "   Current desktop: ${XDG_CURRENT_DESKTOP:-unknown}"
    echo ""
    echo "The workspace manager will still work, but virtual desktop"
    echo "switching will not be available."
    echo ""
    read -p "Continue anyway? [y/N] " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Check dependencies
echo "Checking dependencies..."
MISSING_DEPS=()

if ! command -v wmctrl &> /dev/null && ! command -v xdotool &> /dev/null; then
    MISSING_DEPS+=("wmctrl or xdotool")
fi

if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    echo "⚠️  Missing dependencies: ${MISSING_DEPS[*]}"
    echo ""
    echo "Install with:"
    echo "  sudo apt-get install wmctrl xdotool"
    echo ""
    read -p "Continue without automatic desktop switching? [y/N] " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "✓ Ready to demo"
echo ""

# Setup GNOME
echo "Step 1: Setting up GNOME virtual desktops..."
./gnome-desktop-integration.py setup

echo ""
echo "Step 2: Creating demo workspaces..."

# Create AWS workspace
echo "Creating AWS Production workspace..."
AWS_ID=$(./nubifer-workspace create \
  --name "AWS Production" \
  --provider aws \
  --account-id 111111111111 \
  --account-name "aws-prod" \
  --region us-east-1 | grep "ID:" | awk '{print $2}')

# Create Azure workspace
echo "Creating Azure Development workspace..."
AZURE_ID=$(./nubifer-workspace create \
  --name "Azure Development" \
  --provider azure \
  --account-id "azure-sub-222" \
  --account-name "azure-dev" \
  --region eastus | grep "ID:" | awk '{print $2}')

# Create GCP workspace
echo "Creating GCP Staging workspace..."
GCP_ID=$(./nubifer-workspace create \
  --name "GCP Staging" \
  --provider gcp \
  --account-id "gcp-project-333" \
  --account-name "gcp-staging" \
  --region us-central1 | grep "ID:" | awk '{print $2}')

# Create Oracle workspace (read-only)
echo "Creating Oracle Production workspace (read-only)..."
ORACLE_ID=$(./nubifer-workspace create \
  --name "Oracle Production" \
  --provider oracle \
  --account-id "oracle-tenancy-444" \
  --account-name "oracle-prod" \
  --region us-ashburn-1 \
  --read-only | grep "ID:" | awk '{print $2}')

echo ""
echo "Step 3: Assigning workspaces to virtual desktops..."

# Assign to specific desktops
./gnome-desktop-integration.py assign "$AWS_ID" --desktop 1
./gnome-desktop-integration.py assign "$AZURE_ID" --desktop 2
./gnome-desktop-integration.py assign "$GCP_ID" --desktop 3
./gnome-desktop-integration.py assign "$ORACLE_ID" --desktop 4

echo ""
echo "Step 4: Listing assignments..."
./gnome-desktop-integration.py list

echo ""
echo "=========================================="
echo "✓ Demo Setup Complete!"
echo "=========================================="
echo ""
echo "Now try switching workspaces:"
echo ""
echo "  # Switch to AWS (Desktop 1)"
echo "  ./nubifer-workspace switch $AWS_ID"
echo ""
echo "  # Switch to Azure (Desktop 2)"
echo "  ./nubifer-workspace switch $AZURE_ID"
echo ""
echo "  # Switch to GCP (Desktop 3)"
echo "  ./nubifer-workspace switch $GCP_ID"
echo ""
echo "  # Switch to Oracle (Desktop 4)"
echo "  ./nubifer-workspace switch $ORACLE_ID"
echo ""
echo "Watch your GNOME virtual desktops switch automatically!"
echo ""
echo "You can also use keyboard shortcuts:"
echo "  Super+1, Super+2, Super+3, Super+4"
echo ""
echo "To clean up demo workspaces:"
echo "  rm -rf ~/.config/nubifer/"
echo ""
