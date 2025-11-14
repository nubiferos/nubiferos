# Firejail profile for Azure CLI in NubiferOS workspaces
# Isolates Azure CLI to prevent credential leakage

# Include base NubiferOS profile
include nubifer-base.profile

# Azure CLI specific whitelists

# Allow Azure CLI binary
noblacklist /usr/bin/az
noblacklist /opt/az

# Allow Python (Azure CLI is Python-based)
noblacklist /usr/bin/python3
noblacklist /usr/lib/python3*

# Whitelist workspace-specific Azure config
# This will be set dynamically: whitelist ${HOME}/.azure/workspace-${WORKSPACE_ID}
# This will be set dynamically: whitelist ${HOME}/.config/nubifer/workspaces/${WORKSPACE_ID}.json

# Blacklist other workspaces
# This will be set dynamically for each workspace

# Allow temporary files
whitelist /tmp

# DNS resolution
noblacklist /etc/resolv.conf
noblacklist /etc/hosts

# SSL certificates
noblacklist /etc/ssl
noblacklist /usr/share/ca-certificates

# Seccomp filter for Azure CLI
seccomp.keep @default-keep,@network-io,@system-service

# Memory limits
rlimit-as 2G
rlimit-fsize 500M
