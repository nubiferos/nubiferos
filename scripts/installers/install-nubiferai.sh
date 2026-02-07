#!/bin/bash
# Install NubiferAI - AI assistant framework for cloud resource management
#
# Called by install-selected-tools.sh when the user opts in during installation.
#
# TODO: Replace this placeholder with actual installation steps once the
# nubiferai package/repository is available. Options:
#   - apt install from nubiferos repo: apt-get install -y nubiferai
#   - pip install: pip3 install nubiferai
#   - Binary download from GitHub releases
#   - Local .deb bundled in the ISO

set -e

LOG_FILE="/var/log/nubiferos-tool-install.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [nubiferai] $1" | tee -a "$LOG_FILE"
}

log "Installing NubiferAI..."

# --- Placeholder: replace with actual install steps ---

# Option A: Install from NubiferOS apt repository
# apt-get install -y nubiferai

# Option B: Install via pip
# pip3 install --break-system-packages nubiferai

# Option C: Download binary from GitHub releases
# NUBIFERAI_VERSION="0.1.0"
# curl -fsSL "https://github.com/nubiferos/nubiferai/releases/download/v${NUBIFERAI_VERSION}/nubiferai-linux-amd64.tar.gz" \
#     | tar -xz -C /usr/local/bin/

# Create default config directory (disabled by default)
mkdir -p /etc/nubiferai
cat > /etc/nubiferai/config.yaml << 'CONF'
# NubiferAI Configuration
# AI is disabled by default — enable it in the first-boot wizard or with:
#   nubifer ai enable --provider <provider>
ai:
  enabled: false
  provider: "none"

  security:
    require_approval_for_writes: true
    log_all_queries: true
    filter_sensitive_data: true
    allowed_workspaces: []

  privacy:
    anonymize_account_ids: true
CONF

log "NubiferAI configuration created (AI disabled by default)"
log "NubiferAI installation complete"

exit 0
