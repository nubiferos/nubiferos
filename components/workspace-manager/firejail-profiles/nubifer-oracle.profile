# Firejail profile for Oracle Cloud CLI in NubiferOS workspaces
# Isolates OCI CLI to prevent credential leakage

# Include base NubiferOS profile
include nubifer-base.profile

# Oracle CLI specific whitelists

# Allow OCI CLI binary
noblacklist /usr/local/bin/oci
noblacklist /usr/bin/oci

# Allow Python (OCI CLI is Python-based)
noblacklist /usr/bin/python3
noblacklist /usr/lib/python3*

# Whitelist workspace-specific OCI config
# This will be set dynamically: whitelist ${HOME}/.oci/workspace-${WORKSPACE_ID}
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

# Seccomp filter for OCI CLI
seccomp.keep @default-keep,@network-io,@system-service

# Memory limits
rlimit-as 2G
rlimit-fsize 500M
