#!/bin/bash
# Install k9s - Terminal UI for Kubernetes
# Part of NubiferOS installer scripts

set -e

echo "Installing k9s..."

cd /tmp
K9S_VERSION=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | grep 'tag_name' | cut -d'"' -f4)
curl -sL "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_amd64.tar.gz" | tar xz
mv k9s /usr/local/bin/
chmod +x /usr/local/bin/k9s

echo "✓ k9s ${K9S_VERSION} installed"
k9s version
