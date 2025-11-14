#!/bin/bash
# Enable post-installation tests
# This script is called during installation if test mode is enabled

set -e

echo "Enabling post-installation tests..."

# Create flag file
mkdir -p /etc/nubifer
touch /etc/nubifer/run-post-install-tests

# Install test script
cp /usr/share/nubifer/tests/post-install-tests.sh /usr/local/bin/nubifer-post-install-tests
chmod +x /usr/local/bin/nubifer-post-install-tests

# Install systemd service
cp /usr/share/nubifer/installer/post-install-test.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable post-install-test.service

echo "Post-installation tests will run on first boot"
echo "Results will be in: /var/log/nubifer-test-report.txt"
