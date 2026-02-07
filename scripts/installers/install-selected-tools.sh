#!/bin/bash
# Master installer for external tools (not in Debian repos)
# Called by Calamares after package installation
# Checks for marker files to determine what to install

set -e

INSTALLER_DIR="/usr/share/nubiferos/installers"
LOG_FILE="/var/log/nubiferos-tool-install.log"
MARKER_DIR="/tmp/nubiferos-install-markers"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Create marker directory if it doesn't exist
mkdir -p "$MARKER_DIR"

log "=========================================="
log "NubiferOS External Tool Installation"
log "=========================================="

# Function to install a tool if its marker exists or if it's a default tool
install_if_selected() {
    local tool_name="$1"
    local installer_script="$2"
    local is_default="${3:-false}"
    
    # Check if marker file exists (created by netinstall selection)
    # OR if it's a default tool and no explicit skip marker exists
    if [ -f "$MARKER_DIR/install-$tool_name" ] || \
       ([ "$is_default" = "true" ] && [ ! -f "$MARKER_DIR/skip-$tool_name" ]); then
        if [ -x "$INSTALLER_DIR/$installer_script" ]; then
            log "Installing $tool_name..."
            if "$INSTALLER_DIR/$installer_script" >> "$LOG_FILE" 2>&1; then
                log "✓ $tool_name installed successfully"
            else
                log "⚠ $tool_name installation failed (non-critical)"
            fi
        else
            log "⚠ Installer not found: $installer_script"
        fi
    else
        log "⊘ Skipping $tool_name (not selected)"
    fi
}

# ============================================
# KUBERNETES & CONTAINERS (defaults: kubectl, helm, k9s)
# ============================================
log ""
log "--- Kubernetes & Container Tools ---"
install_if_selected "kubectl" "install-kubectl.sh" "true"
install_if_selected "helm" "install-helm.sh" "true"
install_if_selected "k9s" "install-k9s.sh" "true"
install_if_selected "eksctl" "install-eksctl.sh" "false"
install_if_selected "minikube" "install-minikube.sh" "false"
install_if_selected "kind" "install-kind.sh" "false"

# ============================================
# INFRASTRUCTURE AS CODE (default: terraform)
# ============================================
log ""
log "--- Infrastructure as Code ---"
install_if_selected "terraform" "install-terraform.sh" "true"
install_if_selected "pulumi" "install-pulumi.sh" "false"
install_if_selected "opentofu" "install-opentofu.sh" "false"

# ============================================
# CLOUD SDKS
# ============================================
log ""
log "--- Cloud SDKs ---"
install_if_selected "gcloud" "install-gcloud.sh" "true"
install_if_selected "oci-cli" "install-oci-cli.sh" "false"

# ============================================
# CI/CD & GITOPS
# ============================================
log ""
log "--- CI/CD & GitOps ---"
install_if_selected "gh" "install-github-cli.sh" "true"
install_if_selected "glab" "install-gitlab-cli.sh" "false"
install_if_selected "argocd" "install-argocd.sh" "false"
install_if_selected "flux" "install-flux.sh" "false"
install_if_selected "tekton" "install-tekton.sh" "false"

# ============================================
# SECURITY SCANNING (defaults: trivy, grype)
# ============================================
log ""
log "--- Security Scanning ---"
install_if_selected "trivy" "install-trivy.sh" "true"
install_if_selected "grype" "install-grype.sh" "true"
install_if_selected "syft" "install-syft.sh" "false"
install_if_selected "tfsec" "install-tfsec.sh" "false"
install_if_selected "checkov" "install-checkov.sh" "false"

# ============================================
# MONITORING & OBSERVABILITY
# ============================================
log ""
log "--- Monitoring & Observability ---"
install_if_selected "prometheus" "install-prometheus.sh" "false"
install_if_selected "grafana" "install-grafana.sh" "false"
install_if_selected "loki" "install-loki.sh" "false"
install_if_selected "stern" "install-stern.sh" "false"

# ============================================
# DATABASE CLIENTS
# ============================================
log ""
log "--- Database Clients ---"
install_if_selected "mongosh" "install-mongosh.sh" "false"

# ============================================
# UTILITIES
# ============================================
log ""
log "--- Utilities ---"
install_if_selected "yq" "install-yq.sh" "true"
install_if_selected "httpie" "install-httpie.sh" "false"
install_if_selected "bat" "install-bat.sh" "false"
install_if_selected "ripgrep" "install-ripgrep.sh" "false"
install_if_selected "fd" "install-fd.sh" "false"
install_if_selected "fzf" "install-fzf.sh" "false"

# ============================================
# SECRETS MANAGEMENT
# ============================================
log ""
log "--- Secrets Management ---"
install_if_selected "vault" "install-vault.sh" "false"
install_if_selected "sops" "install-sops.sh" "false"
install_if_selected "age" "install-age.sh" "false"
install_if_selected "aws-vault" "install-aws-vault.sh" "false"

# ============================================
# GRAPHICAL IDES
# ============================================
log ""
log "--- Graphical IDEs ---"
install_if_selected "vscode" "install-vscode.sh" "false"
install_if_selected "vscodium" "install-vscodium.sh" "false"
install_if_selected "intellij" "install-intellij.sh" "false"
install_if_selected "pycharm" "install-pycharm.sh" "false"

# ============================================
# PROGRAMMING LANGUAGES
# ============================================
log ""
log "--- Programming Languages ---"
install_if_selected "go" "install-go.sh" "false"
install_if_selected "rust" "install-rust.sh" "false"

# ============================================
# TESTING TOOLS
# ============================================
log ""
log "--- Testing Tools ---"
install_if_selected "k6" "install-k6.sh" "false"
install_if_selected "newman" "install-newman.sh" "false"

# ============================================
# AI ASSISTANT
# ============================================
log ""
log "--- AI Assistant ---"
install_if_selected "nubiferai" "install-nubiferai.sh" "true"

log ""
log "=========================================="
log "External tool installation complete!"
log "=========================================="

exit 0
