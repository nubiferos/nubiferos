#!/bin/bash
# Install kubectl - Kubernetes command-line tool
# Part of NubiferOS installer scripts

set -e

echo "Installing kubectl..."

cd /tmp
KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl.sha256"

# Verify checksum
echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check

install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm -f kubectl kubectl.sha256

echo "✓ kubectl ${KUBECTL_VERSION} installed"
kubectl version --client
