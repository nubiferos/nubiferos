# Firejail profile for Google Cloud CLI in NubiferOS workspaces
# Isolates gcloud CLI to prevent credential leakage

# Include base NubiferOS profile
include nubifer-base.profile

# GCP CLI specific whitelists

# Allow gcloud binary
noblacklist /usr/bin/gcloud
noblacklist /usr/lib/google-cloud-sdk

# Allow Python (gcloud is Python-based)
noblacklist /usr/bin/python3
noblacklist /usr/lib/python3*

# Whitelist workspace-specific GCP config
# This will be set dynamically: whitelist ${HOME}/.config/gcloud/workspace-${WORKSPACE_ID}
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

# Seccomp filter for gcloud
seccomp.keep @default-keep,@network-io,@system-service

# Memory limits
rlimit-as 2G
rlimit-fsize 500M
