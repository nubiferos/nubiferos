#!/bin/bash
# NubiferOS Development Deployment Script
# Push component changes to a running NubiferOS VM for fast iteration
#
# Usage: ./dev-deploy.sh [component] [vm-address]
# Example: ./dev-deploy.sh context-indicator 192.168.1.100
#          ./dev-deploy.sh all nubifer-vm.local

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Default VM settings (override with environment variables or arguments)
VM_USER="${NUBIFER_VM_USER:-installer}"
VM_HOST="${NUBIFER_VM_HOST:-}"
VM_PORT="${NUBIFER_VM_PORT:-22}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() { echo -e "${GREEN}[DEV]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

show_help() {
    cat << 'EOF'
NubiferOS Development Deployment Script

USAGE:
    ./dev-deploy.sh <component> <vm-address>
    ./dev-deploy.sh all <vm-address>

COMPONENTS:
    context-indicator   - GNOME Shell extension for workspace display
    context-manager     - D-Bus service for workspace management
    credential-manager  - D-Bus service for credential storage
    prompt              - Terminal prompt integration
    all                 - Deploy all components

EXAMPLES:
    # Deploy context indicator to VM
    ./dev-deploy.sh context-indicator 192.168.1.100

    # Deploy all components
    ./dev-deploy.sh all nubifer-dev.local

    # Using environment variables
    export NUBIFER_VM_HOST=192.168.1.100
    export NUBIFER_VM_USER=myuser
    ./dev-deploy.sh context-manager

ENVIRONMENT VARIABLES:
    NUBIFER_VM_HOST  - VM hostname or IP (required if not passed as argument)
    NUBIFER_VM_USER  - SSH username (default: installer)
    NUBIFER_VM_PORT  - SSH port (default: 22)

PREREQUISITES:
    1. SSH access to the VM (ssh-copy-id recommended)
    2. User must have sudo access on the VM
    3. VM should have NubiferOS or Debian with GNOME installed

EOF
}

# Check SSH connection
check_ssh() {
    log "Checking SSH connection to ${VM_USER}@${VM_HOST}..."
    if ! ssh -p "$VM_PORT" -o ConnectTimeout=5 "${VM_USER}@${VM_HOST}" "echo 'SSH OK'" &>/dev/null; then
        error "Cannot connect to VM. Check:
  - VM is running and has network
  - SSH is enabled: sudo systemctl start ssh
  - Firewall allows SSH: sudo ufw allow ssh
  - SSH key is set up: ssh-copy-id ${VM_USER}@${VM_HOST}"
    fi
    log "SSH connection OK"
}

# Deploy context indicator (GNOME extension)
deploy_context_indicator() {
    log "Deploying Context Indicator (GNOME Extension)..."

    local SRC="${PROJECT_ROOT}/components/context-indicator"
    local DEST="~/.local/share/gnome-shell/extensions/nubiferos-context@nubiferos.org"

    # Create extension directory and copy files
    ssh -p "$VM_PORT" "${VM_USER}@${VM_HOST}" "mkdir -p ${DEST}"
    scp -P "$VM_PORT" -r "${SRC}/gnome-extension/"* "${VM_USER}@${VM_HOST}:${DEST}/"

    # Enable the extension
    ssh -p "$VM_PORT" "${VM_USER}@${VM_HOST}" "gnome-extensions enable nubiferos-context@nubiferos.org 2>/dev/null || true"

    log "Context Indicator deployed. Restart GNOME Shell to activate:"
    log "  - X11: Press Alt+F2, type 'r', press Enter"
    log "  - Wayland: Log out and log back in"
}

# Deploy context manager service
deploy_context_manager() {
    log "Deploying Context Manager Service..."

    local SRC="${PROJECT_ROOT}/components/context-manager"
    local REMOTE_TMP="/tmp/nubifer-context-manager"

    # Copy source files
    ssh -p "$VM_PORT" "${VM_USER}@${VM_HOST}" "rm -rf ${REMOTE_TMP} && mkdir -p ${REMOTE_TMP}"
    scp -P "$VM_PORT" -r "${SRC}/src/"* "${VM_USER}@${VM_HOST}:${REMOTE_TMP}/"
    scp -P "$VM_PORT" "${SRC}/requirements.txt" "${VM_USER}@${VM_HOST}:${REMOTE_TMP}/"
    scp -P "$VM_PORT" -r "${SRC}/systemd/"* "${VM_USER}@${VM_HOST}:${REMOTE_TMP}/"

    # Install on VM
    ssh -p "$VM_PORT" "${VM_USER}@${VM_HOST}" << 'REMOTE_SCRIPT'
        set -e
        cd /tmp/nubifer-context-manager

        # Install Python dependencies
        pip3 install --user -r requirements.txt 2>/dev/null || sudo pip3 install -r requirements.txt

        # Install CLI and service
        sudo mkdir -p /usr/lib/nubiferos/context-manager
        sudo cp *.py /usr/lib/nubiferos/context-manager/
        sudo cp cli.py /usr/local/bin/nubifer-workspace
        sudo chmod +x /usr/local/bin/nubifer-workspace

        # Install systemd service (user service)
        mkdir -p ~/.config/systemd/user
        cp org.nubiferos.ContextManager.service ~/.config/systemd/user/
        systemctl --user daemon-reload
        systemctl --user restart org.nubiferos.ContextManager.service || true

        echo "Context Manager installed"
REMOTE_SCRIPT

    log "Context Manager deployed and service restarted"
}

# Deploy credential manager service
deploy_credential_manager() {
    log "Deploying Credential Manager Service..."

    local SRC="${PROJECT_ROOT}/components/credential-manager"
    local REMOTE_TMP="/tmp/nubifer-credential-manager"

    # Copy source files
    ssh -p "$VM_PORT" "${VM_USER}@${VM_HOST}" "rm -rf ${REMOTE_TMP} && mkdir -p ${REMOTE_TMP}"
    scp -P "$VM_PORT" -r "${SRC}/src/"* "${VM_USER}@${VM_HOST}:${REMOTE_TMP}/"
    scp -P "$VM_PORT" "${SRC}/requirements.txt" "${VM_USER}@${VM_HOST}:${REMOTE_TMP}/"
    scp -P "$VM_PORT" "${SRC}/nubifer-creds" "${VM_USER}@${VM_HOST}:${REMOTE_TMP}/"
    scp -P "$VM_PORT" -r "${SRC}/systemd/"* "${VM_USER}@${VM_HOST}:${REMOTE_TMP}/"

    # Install on VM
    ssh -p "$VM_PORT" "${VM_USER}@${VM_HOST}" << 'REMOTE_SCRIPT'
        set -e
        cd /tmp/nubifer-credential-manager

        # Install Python dependencies
        pip3 install --user -r requirements.txt 2>/dev/null || sudo pip3 install -r requirements.txt

        # Install CLI and service
        sudo mkdir -p /usr/lib/nubiferos/credential-manager
        sudo cp *.py /usr/lib/nubiferos/credential-manager/
        sudo cp nubifer-creds /usr/local/bin/
        sudo chmod +x /usr/local/bin/nubifer-creds

        # Install systemd service (user service)
        mkdir -p ~/.config/systemd/user
        cp org.nubiferos.CredentialManager.service ~/.config/systemd/user/
        systemctl --user daemon-reload
        systemctl --user restart org.nubiferos.CredentialManager.service || true

        echo "Credential Manager installed"
REMOTE_SCRIPT

    log "Credential Manager deployed and service restarted"
}

# Deploy terminal prompt integration
deploy_prompt() {
    log "Deploying Terminal Prompt Integration..."

    local SRC="${PROJECT_ROOT}/components/context-indicator/nubiferos-prompt.sh"

    scp -P "$VM_PORT" "${SRC}" "${VM_USER}@${VM_HOST}:/tmp/nubiferos-prompt.sh"
    ssh -p "$VM_PORT" "${VM_USER}@${VM_HOST}" "sudo cp /tmp/nubiferos-prompt.sh /etc/profile.d/"

    log "Prompt integration deployed. Open a new terminal to see changes."
}

# Deploy all components
deploy_all() {
    log "Deploying ALL NubiferOS components..."
    deploy_credential_manager
    deploy_context_manager
    deploy_context_indicator
    deploy_prompt
    log "All components deployed!"
}

# Main
main() {
    local COMPONENT="${1:-}"
    local HOST_ARG="${2:-}"

    # Handle help
    if [[ "$COMPONENT" == "-h" || "$COMPONENT" == "--help" || -z "$COMPONENT" ]]; then
        show_help
        exit 0
    fi

    # Set VM host from argument or environment
    if [[ -n "$HOST_ARG" ]]; then
        VM_HOST="$HOST_ARG"
    fi

    if [[ -z "$VM_HOST" ]]; then
        error "VM host not specified. Use: ./dev-deploy.sh <component> <vm-address>
Or set NUBIFER_VM_HOST environment variable."
    fi

    # Check SSH connection first
    check_ssh

    # Deploy requested component
    case "$COMPONENT" in
        context-indicator)
            deploy_context_indicator
            ;;
        context-manager)
            deploy_context_manager
            ;;
        credential-manager)
            deploy_credential_manager
            ;;
        prompt)
            deploy_prompt
            ;;
        all)
            deploy_all
            ;;
        *)
            error "Unknown component: $COMPONENT
Valid components: context-indicator, context-manager, credential-manager, prompt, all"
            ;;
    esac

    log "Deployment complete!"
}

main "$@"
