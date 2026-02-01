#!/bin/bash
# Install Podman Desktop - Container management GUI
# https://podman-desktop.io/

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[podman-desktop]${NC} $1"; }
warn() { echo -e "${YELLOW}[podman-desktop]${NC} $1"; }
error() { echo -e "${RED}[podman-desktop]${NC} $1"; }

# Check if already installed
if command -v podman-desktop &>/dev/null || [ -f /usr/bin/podman-desktop ]; then
    log "Podman Desktop is already installed"
    exit 0
fi

log "Installing Podman Desktop..."

# Ensure podman is installed first
if ! command -v podman &>/dev/null; then
    log "Installing podman first..."
    sudo apt-get update
    sudo apt-get install -y podman
fi

ARCH=$(uname -m)
case "$ARCH" in
    x86_64) ARCH="x64" ;;
    aarch64) ARCH="arm64" ;;
    *) error "Unsupported architecture: $ARCH"; exit 1 ;;
esac

# Get latest release
log "Fetching latest Podman Desktop release..."
RELEASE_URL="https://api.github.com/repos/containers/podman-desktop/releases/latest"
VERSION=$(curl -sSL "$RELEASE_URL" | grep '"tag_name"' | head -1 | cut -d'"' -f4 | tr -d 'v')

if [ -z "$VERSION" ]; then
    error "Could not determine latest version"
    exit 1
fi

log "Latest version: $VERSION"

# Download flatpak (most reliable for desktop apps)
if command -v flatpak &>/dev/null; then
    log "Installing via Flatpak..."
    flatpak install -y flathub io.podman_desktop.PodmanDesktop
    log "Podman Desktop installed via Flatpak"
    exit 0
fi

# Fallback: Download AppImage
APPIMAGE_URL="https://github.com/containers/podman-desktop/releases/download/v${VERSION}/podman-desktop-${VERSION}-${ARCH}.AppImage"
INSTALL_DIR="/opt/podman-desktop"
APPIMAGE_PATH="${INSTALL_DIR}/podman-desktop.AppImage"

log "Downloading AppImage..."
sudo mkdir -p "$INSTALL_DIR"
sudo curl -sSL -o "$APPIMAGE_PATH" "$APPIMAGE_URL"
sudo chmod +x "$APPIMAGE_PATH"

# Create symlink
sudo ln -sf "$APPIMAGE_PATH" /usr/local/bin/podman-desktop

# Create desktop entry
cat << 'EOF' | sudo tee /usr/share/applications/podman-desktop.desktop > /dev/null
[Desktop Entry]
Name=Podman Desktop
Comment=Manage containers and Kubernetes
Exec=/opt/podman-desktop/podman-desktop.AppImage --no-sandbox
Icon=podman
Terminal=false
Type=Application
Categories=Containers;Development;System;
Keywords=podman;docker;containers;kubernetes;
EOF

log "Podman Desktop installed successfully!"
log "Launch from Applications menu or run: podman-desktop"
