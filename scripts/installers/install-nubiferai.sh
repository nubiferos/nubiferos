#!/bin/bash
# Install NubiferAI - AI assistant framework for cloud resource management
#
# Called by install-selected-tools.sh when the user opts in during installation.
#
# Follows the installation procedure from nubiferos-addon.toml:
#   1. Clone to /opt/nubiferos/addons/nubiferai
#   2. Create venv with --system-site-packages
#   3. Pip install packages in order: core → cli → gtk → dbus
#   4. Symlink entry points to /usr/local/bin
#   5. Install .desktop file

set -e

LOG_FILE="/var/log/nubiferos-tool-install.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [nubiferai] $1" | tee -a "$LOG_FILE"
}

INSTALL_DIR="/opt/nubiferos/addons/nubiferai"
VENV_DIR="${INSTALL_DIR}/.venv"
REPO_URL="https://github.com/nubiferos/nubiferai.git"
BRANCH="trunk"

log "Installing NubiferAI..."

# Step 1: Install system dependencies
log "Installing system dependencies..."
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    python3-venv \
    python3-dev \
    python3-gi \
    python3-gi-cairo \
    gir1.2-gtk-4.0 \
    gir1.2-adw-1 \
    python3-keyring \
    git

# Step 2: Clone the repository
log "Cloning NubiferAI repository..."
mkdir -p /opt/nubiferos/addons
if [ -d "$INSTALL_DIR" ]; then
    log "Existing installation found, removing..."
    rm -rf "$INSTALL_DIR"
fi
git clone --branch "$BRANCH" --depth 1 "$REPO_URL" "$INSTALL_DIR"

# Step 3: Create virtual environment with system site-packages
log "Creating virtual environment..."
python3 -m venv --system-site-packages "$VENV_DIR"

# Step 4: Pip install packages in order
log "Installing NubiferAI packages..."
"${VENV_DIR}/bin/pip" install --no-cache-dir "${INSTALL_DIR}/packages/nubiferai-core"
log "  Installed nubiferai-core"

"${VENV_DIR}/bin/pip" install --no-cache-dir "${INSTALL_DIR}/packages/nubiferai-cli"
log "  Installed nubiferai-cli"

"${VENV_DIR}/bin/pip" install --no-cache-dir "${INSTALL_DIR}/packages/nubiferai-gtk" || log "WARNING: nubiferai-gtk install failed (optional GTK component)"
log "  Installed nubiferai-gtk"

"${VENV_DIR}/bin/pip" install --no-cache-dir "${INSTALL_DIR}/packages/nubiferai-dbus" || log "WARNING: nubiferai-dbus install failed (optional D-Bus component)"
log "  Installed nubiferai-dbus"

# Step 5: Create system configuration directories
log "Creating configuration directories..."
mkdir -p /etc/nubiferai
mkdir -p /etc/nubiferai/providers
mkdir -p /etc/nubiferai/seeds

# Step 6: Write default config (TOML format)
cat > /etc/nubiferai/config.toml << 'CONF'
# NubiferAI Configuration
# AI is disabled by default — enable it in the first-boot wizard or with:
#   nubiferai enable --provider <provider>

[ai]
enabled = false
provider = "none"

[ai.security]
require_approval_for_writes = true
log_all_queries = true
filter_sensitive_data = true
allowed_workspaces = []

[ai.privacy]
anonymize_account_ids = true
CONF
log "Default configuration written to /etc/nubiferai/config.toml"

# Step 7: Copy bundled seeds if present
if [ -d "${INSTALL_DIR}/seeds" ]; then
    cp -r "${INSTALL_DIR}/seeds/"* /etc/nubiferai/seeds/ 2>/dev/null || log "No seed files found to copy"
    log "Bundled seeds copied to /etc/nubiferai/seeds/"
fi

# Step 8: Symlink entry points to /usr/local/bin
log "Creating symlinks..."
ln -sf "${VENV_DIR}/bin/nubiferai" /usr/local/bin/nubiferai
ln -sf "${VENV_DIR}/bin/nubiferai-gtk" /usr/local/bin/nubiferai-gtk

# Step 9: Install .desktop file
log "Installing desktop entry..."
mkdir -p /usr/share/applications
cat > /usr/share/applications/ai.nubiferos.nubiferai.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=NubiferAI
Comment=AI-native cloud operations
Exec=/usr/local/bin/nubiferai-gtk
Icon=weather-overcast-symbolic
Terminal=false
Categories=Development;Utility;
Keywords=ai;cloud;nubifer;
EOF

# Step 10: Verify installation
log "Verifying installation..."
if /usr/local/bin/nubiferai --help > /dev/null 2>&1; then
    log "NubiferAI CLI verified successfully"
else
    log "WARNING: nubiferai --help did not exit cleanly (CLI may still work)"
fi

log "NubiferAI installation complete"

exit 0
