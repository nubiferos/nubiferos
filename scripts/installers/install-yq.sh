#!/bin/bash
# Install yq YAML processor
set -e

echo "Installing yq..."

YQ_VERSION=$(curl -s https://api.github.com/repos/mikefarah/yq/releases/latest | grep tag_name | cut -d '"' -f 4)
curl -fsSL "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64" -o /usr/local/bin/yq
chmod +x /usr/local/bin/yq

echo "✓ yq installed"
yq --version
