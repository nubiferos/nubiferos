#!/bin/bash
# Install Helm - Kubernetes package manager
# Part of NubiferOS installer scripts

set -e

echo "Installing Helm..."

curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

echo "✓ Helm installed"
helm version
