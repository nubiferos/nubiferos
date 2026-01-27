#!/bin/bash
# Install eksctl - Amazon EKS cluster management tool

set -e

echo "Installing eksctl..."

cd /tmp
curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz"
tar -xzf eksctl_Linux_amd64.tar.gz
mv eksctl /usr/local/bin/
rm eksctl_Linux_amd64.tar.gz

# Verify installation
if eksctl version &>/dev/null; then
    echo "eksctl installed successfully: $(eksctl version)"
else
    echo "eksctl installation failed"
    exit 1
fi
