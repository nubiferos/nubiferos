# Firejail profile for AWS CLI in NubiferOS workspaces
# Isolates AWS CLI to prevent credential leakage

# Include base NubiferOS profile
include nubifer-base.profile

# Workspace-specific configuration will be injected at runtime
# Format: nubifer-aws-<workspace-id>.profile

# AWS CLI specific whitelists
# These will be customized per workspace by the workspace manager

# Allow AWS CLI binary
noblacklist /usr/local/bin/aws
noblacklist /usr/local/aws-cli
noblacklist /usr/bin/aws

# Allow Python (AWS CLI is Python-based)
noblacklist /usr/bin/python3
noblacklist /usr/lib/python3*

# Whitelist workspace-specific AWS config
# This will be set dynamically: whitelist ${HOME}/.aws/workspace-${WORKSPACE_ID}
# This will be set dynamically: whitelist ${HOME}/.config/nubifer/workspaces/${WORKSPACE_ID}.json

# Blacklist other workspaces (prevent cross-workspace access)
# This will be set dynamically for each workspace

# Allow temporary files for AWS CLI
whitelist /tmp

# DNS resolution
noblacklist /etc/resolv.conf
noblacklist /etc/hosts

# SSL certificates
noblacklist /etc/ssl
noblacklist /usr/share/ca-certificates

# Network restrictions
# Allow only AWS endpoints (can be further restricted by region)
# This provides defense-in-depth even if credentials leak

# Seccomp filter for AWS CLI
# Allow only necessary system calls
seccomp.keep @default-keep,@network-io,@system-service

# Memory limits for AWS CLI
rlimit-as 2G
rlimit-fsize 500M
