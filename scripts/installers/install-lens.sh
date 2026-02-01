#!/bin/bash
# Install Lens - The Kubernetes IDE
# https://k8slens.dev/

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[lens]${NC} $1"; }
warn() { echo -e "${YELLOW}[lens]${NC} $1"; }
error() { echo -e "${RED}[lens]${NC} $1"; }

# Check if already installed
if command -v lens &>/dev/null || [ -f /usr/bin/lens ] || [ -f /opt/Lens/lens ]; then
    log "Lens is already installed"
    lens --version 2>/dev/null || true
    exit 0
fi

log "Installing Lens - The Kubernetes IDE..."

# Lens is now called OpenLens (open source fork) or Lens Desktop (commercial)
# We'll install OpenLens from the community releases

ARCH=$(uname -m)
case "$ARCH" in
    x86_64) ARCH="amd64" ;;
    aarch64) ARCH="arm64" ;;
    *) error "Unsupported architecture: $ARCH"; exit 1 ;;
esac

# Get latest OpenLens release
log "Fetching latest OpenLens release..."
RELEASE_URL="https://api.github.com/repos/MuhammedKalworker/OpenLens/releases/latest"
DOWNLOAD_URL=$(curl -sSL "$RELEASE_URL" | grep "browser_download_url.*${ARCH}.*\.deb" | head -1 | cut -d'"' -f4)

if [ -z "$DOWNLOAD_URL" ]; then
    # Fallback: try the official Lens snap
    warn "OpenLens .deb not found, trying snap..."
    if command -v snap &>/dev/null; then
        sudo snap install kontena-lens --classic
        log "Lens installed via snap"
        exit 0
    else
        error "Could not find Lens package. Install manually from https://k8slens.dev/"
        exit 1
    fi
fi

# Download and install
TEMP_DEB=$(mktemp --suffix=.deb)
log "Downloading from: $DOWNLOAD_URL"
curl -sSL -o "$TEMP_DEB" "$DOWNLOAD_URL"

log "Installing package..."
sudo dpkg -i "$TEMP_DEB" || sudo apt-get install -f -y
rm -f "$TEMP_DEB"

log "Lens installed successfully!"
log "Launch from Applications menu or run: lens"
