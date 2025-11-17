#!/bin/bash
# Install NICE DCV on NubiferOS test instance
# This script runs automatically via EC2 user data

set -e

LOG_FILE="/var/log/nice-dcv-install.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log "=========================================="
log "NICE DCV Installation Starting"
log "=========================================="

# Wait for system to be ready
log "Waiting for system initialization..."
sleep 30

# Update package lists
log "Updating package lists..."
apt-get update

# Install dependencies
log "Installing dependencies..."
apt-get install -y wget curl

# Download NICE DCV
log "Downloading NICE DCV..."
cd /tmp
wget https://d1uj6qtbmh3dt5.cloudfront.net/nice-dcv-ubuntu2204-x86_64.tgz

# Extract
log "Extracting NICE DCV..."
tar -xvzf nice-dcv-ubuntu*.tgz
cd nice-dcv-*-x86_64

# Install NICE DCV server
log "Installing NICE DCV server..."
apt-get install -y ./nice-dcv-server_*.deb

# Install NICE DCV web viewer
log "Installing NICE DCV web viewer..."
apt-get install -y ./nice-dcv-web-viewer_*.deb || true

# Configure NICE DCV
log "Configuring NICE DCV..."

# Enable and start service
systemctl enable dcvserver
systemctl start dcvserver

# Wait for DCV to start
sleep 10

# Create DCV session for live user
log "Creating DCV session..."
dcv create-session --type=console --owner live live-session || true

# Get public IP
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

log "=========================================="
log "✅ NICE DCV Installation Complete!"
log "=========================================="
log "Connect to: https://${PUBLIC_IP}:8443"
log "Username: live"
log "Password: live"
log "=========================================="

# Write connection info to file
cat > /home/live/connection-info.txt << EOF
NubiferOS Test Instance

NICE DCV Connection:
  URL: https://${PUBLIC_IP}:8443
  Username: live
  Password: live

Instance Details:
  Instance ID: $(curl -s http://169.254.169.254/latest/meta-data/instance-id)
  Region: $(curl -s http://169.254.169.254/latest/meta-data/placement/region)
  Type: $(curl -s http://169.254.169.254/latest/meta-data/instance-type)

Auto-termination: 4 hours from launch
EOF

chown live:live /home/live/connection-info.txt

log "Connection info saved to /home/live/connection-info.txt"
