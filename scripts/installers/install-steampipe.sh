#!/bin/bash
# Install Steampipe - SQL for Cloud APIs
# https://steampipe.io/

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[steampipe]${NC} $1"; }
warn() { echo -e "${YELLOW}[steampipe]${NC} $1"; }
error() { echo -e "${RED}[steampipe]${NC} $1"; }

# Check if already installed
if command -v steampipe &>/dev/null; then
    log "Steampipe is already installed"
    steampipe --version
    exit 0
fi

log "Installing Steampipe - SQL for Cloud APIs..."

# Install via official script
curl -sSL https://raw.githubusercontent.com/turbot/steampipe/main/install.sh | sh

if ! command -v steampipe &>/dev/null; then
    error "Installation failed"
    exit 1
fi

log "Steampipe installed successfully!"
steampipe --version

log ""
log "Installing common plugins..."

# Install AWS plugin
log "Installing AWS plugin..."
steampipe plugin install aws || warn "AWS plugin install failed (may need credentials)"

# Install Azure plugin
log "Installing Azure plugin..."
steampipe plugin install azure || warn "Azure plugin install failed"

# Install GCP plugin
log "Installing GCP plugin..."
steampipe plugin install gcp || warn "GCP plugin install failed"

# Install Kubernetes plugin
log "Installing Kubernetes plugin..."
steampipe plugin install kubernetes || warn "Kubernetes plugin install failed"

log ""
log "=========================================="
log "Steampipe Installation Complete!"
log "=========================================="
log ""
log "Quick start:"
log "  steampipe query                    # Start interactive SQL shell"
log "  steampipe query \"select * from aws_s3_bucket\""
log ""
log "Example queries:"
log "  # Find unencrypted S3 buckets"
log "  select name from aws_s3_bucket where server_side_encryption_configuration is null;"
log ""
log "  # List EC2 instances by region"
log "  select region, count(*) from aws_ec2_instance group by region;"
log ""
log "  # Find public security groups"
log "  select group_id, group_name from aws_vpc_security_group_rule where cidr_ipv4 = '0.0.0.0/0';"
log ""
log "More plugins: https://hub.steampipe.io/plugins"
log "=========================================="
