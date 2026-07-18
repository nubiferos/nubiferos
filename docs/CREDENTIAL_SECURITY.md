# NubiferOS Credential & Secrets Management

## Overview

NubiferOS provides a comprehensive, secure credential management system for cloud accounts, API keys, database credentials, and other secrets. The system integrates with the cloud CLIs and development tools while maintaining security best practices.

The command-line entry point is `nubifer-creds`, a thin, auditable wrapper around `pass` (password-store). Its full command surface is: `add`, `list`, `get`, `remove`, and `token` — see the [Credential Setup Guide](guides/CREDENTIAL_SETUP.md) for a hands-on walkthrough.

## Security Architecture

### Multi-Layer Security

1. **GPG Encryption** - Every secret encrypted at rest with your GPG key (battle-tested, audited tooling — no custom cryptography)
2. **pass (password-store)** - Standard, widely-audited storage backend
3. **LUKS Encryption** - Full disk encryption
4. **Workspace Isolation** - Credentials isolated per workspace
5. **Temporary Credentials** - STS token mode for AWS (enabled by default)

### Credential Storage Hierarchy

```
~/.password-store/ (each leaf is a GPG-encrypted file)
  └── nubifer/
      └── <workspace-id>/
          ├── cloud/
          │   ├── aws/<profile>/
          │   │   ├── access-key-id
          │   │   └── secret-access-key
          │   ├── azure/<name>/
          │   │   ├── tenant-id
          │   │   ├── client-id
          │   │   └── client-secret
          │   └── gcp/<name>/
          │       ├── project-id
          │       └── service-account-key
          └── api/<service>/
              ├── token
              └── scopes
```

Anything else (database passwords, SSH passphrases, certificates) can be stored under the same workspace prefix with standard `pass` commands — see the sections below.

## Credential Types & Best Practices

### 1. AWS Credentials

#### Recommended Approach: Short-Lived Credentials

AWS SSO (IAM Identity Center) is the gold standard for interactive access — no long-lived credentials, centralized access management, MFA enforced, automatic credential rotation. `nubifer-creds` does not yet integrate SSO; on NubiferOS the shipped mechanism for short-lived credentials is **STS token mode**, which is enabled automatically when you add access keys (see below).

#### Alternative: IAM Access Keys (Secured)
```bash
# Add AWS access keys (encrypted in the pass store)
nubifer-creds add -t aws -n production \
  --access-key-id AKIA... \
  --secret-access-key <secret>

# Or just run `nubifer-creds add -t aws -n production` and enter the
# values at the prompts (hidden input — keeps them out of shell history)
```

**Security Measures**:
- Keys encrypted at rest with your GPG key (via pass)
- Keys never written to disk unencrypted
- STS token mode enabled by default — the base keys stay protected
- Audit logging of key usage (`~/.config/nubifer/audit.log`)
- Rotate manually on a schedule (see [Credential Rotation](#credential-rotation))

#### AWS Temporary Credentials (Default - Enabled Automatically)

NubiferOS uses STS temporary credentials by default for enhanced security:

```bash
# Add credentials - STS token mode enabled automatically
nubifer-creds add -t aws -n production
# Enter access key and secret when prompted
# Output: "✓ STS token mode enabled (default)"

# Check token status
nubifer-creds token status -t aws -n production

# Force token refresh
nubifer-creds token refresh -t aws -n production

# Disable STS mode (use static credentials instead)
nubifer-creds add -t aws -n legacy-profile --no-sts
```

**How it works**:
- Base credentials stored encrypted in pass (never leave the helper process)
- AWS CLI calls `nubifer-aws-credential-helper` via `credential_process`
- Helper generates STS session token using base credentials
- Temporary token (1-hour default) returned to AWS CLI
- Tokens cached and auto-refresh when within 5 minutes of expiry

**Benefits**:
- Base credentials never exposed to child processes
- Leaked temporary tokens expire automatically
- Combined with Firejail isolation for defense in depth

#### Manual Token Operations
```bash
# Enable token mode with a custom duration (900–43200 seconds)
nubifer-creds token enable -t aws -n production --duration 3600

# Disable token mode (revert to static credentials)
nubifer-creds token disable -t aws -n production

# Drop the cached token (a new one is minted on next use)
nubifer-creds token clear -t aws -n production
```

All token subcommands accept `-w <workspace-id>` to target a non-active workspace. Role assumption is not integrated into `nubifer-creds` — use the AWS CLI directly (`aws sts assume-role ...`); the session credentials it returns auto-expire.

### 2. Azure Credentials

#### Recommended Approach: Azure CLI with Device Code Flow
```bash
# Login with device code (MFA supported) — handled by az itself,
# nothing is stored in nubifer-creds
az login --use-device-code

# Or use a service principal (for automation) — stored encrypted:
nubifer-creds add -t azure -n automation \
  --tenant-id <tenant-id> \
  --client-id <client-id> \
  --client-secret <secret>
```

#### Managed Identity (for Azure VMs)

On Azure VMs, prefer managed identity — the VM authenticates as itself, so there are no credentials to store locally and nothing to add to `nubifer-creds`.

### 3. GCP Credentials

#### Recommended Approach: Application Default Credentials (ADC)
```bash
# Login with user account — handled by gcloud itself
gcloud auth application-default login

# Or use a service account key (encrypted):
nubifer-creds add -t gcp -n my-project \
  --project-id my-project \
  --key-file service-account.json

# Key file encrypted and stored in the pass store
# Original file securely deleted after import
```

#### Workload Identity (for GKE)

On GKE, prefer workload identity — pods authenticate via their Kubernetes service account, so there are no keys to store locally.

### 4. API Keys & Tokens

#### GitHub/GitLab Personal Access Tokens
```bash
# Add GitHub token (encrypted; prompts for the token with hidden input)
nubifer-creds add -t api -n github --scopes "repo,workflow"

# Add GitLab token
nubifer-creds add -t api -n gitlab --scopes "api,read_repository"

# Retrieve when needed (treat the output as a secret)
pass show nubifer/<workspace-id>/api/github/token
```

#### Monitoring & Observability
```bash
# Services with multiple secrets get one entry per secret:

# Datadog API key
nubifer-creds add -t api -n datadog

# Datadog application key
nubifer-creds add -t api -n datadog-app

# New Relic license key
nubifer-creds add -t api -n newrelic
```

#### Container Registries
```bash
# Store the registry password/token as an API credential
nubifer-creds add -t api -n dockerhub

# Log in without the secret touching shell history or plaintext files
pass show nubifer/<workspace-id>/api/dockerhub/token | \
  docker login -u <user> --password-stdin
```

### 5. Database Credentials

The `db` credential type is reserved in the CLI but has no dedicated handler yet. Store database secrets directly in the pass store under the workspace prefix:

```bash
# PostgreSQL password
pass insert nubifer/<workspace-id>/db/postgres-main/password

# MongoDB connection string (multiline-safe)
pass insert -m nubifer/<workspace-id>/db/mongo-main/connection-string

# Retrieve for a client without exposing it on the command line
PGPASSWORD=$(pass show nubifer/<workspace-id>/db/postgres-main/password) psql -h db.example.com -U dbuser mydb
```

### 6. SSH Keys

The `ssh` credential type is likewise reserved but not yet implemented. Keep private keys in `~/.ssh` (protected by LUKS full-disk encryption) and store passphrases in the pass store:

```bash
pass insert nubifer/<workspace-id>/ssh/github/passphrase
```

## Integration with CLIs & SDKs

### Automatic Credential Injection

#### AWS CLI/SDK
```bash
# Credentials automatically available
aws s3 ls  # Uses credentials from current workspace

# Behind the scenes:
# - The NubiferOS `aws` wrapper writes a temporary config pointing at
#   credential_process = nubifer-aws-credential-helper
# - The helper decrypts from pass and returns STS tokens (or static keys)
# - Secrets never appear in environment variables or plaintext files
# - Region comes from the workspace, not the credential
```

#### Azure CLI/SDK
```bash
# After az login, the Azure CLI manages its own token cache
az vm list

# Behind the scenes:
# - The workspace environment supplies the subscription context
# - Service principal secrets stay encrypted in pass until you retrieve them
# - Azure credential injection is less integrated than AWS's
#   credential_process flow today
```

#### GCP CLI/SDK
```bash
# After gcloud auth, ADC handles authentication
gcloud compute instances list

# Behind the scenes:
# - The workspace environment supplies the project context
# - Service account keys stay encrypted in pass until you retrieve them
```

#### Terraform
```bash
# AWS: Terraform's AWS provider uses the same AWS config flow as the CLI
terraform plan

# Azure/GCP: supply credentials explicitly — retrieve them with
# `nubifer-creds get -t azure -n <name> --json` (treat output as a secret)
```

#### Docker/Podman
```bash
# No automatic registry login — pipe the stored secret in explicitly:
pass show nubifer/<workspace-id>/api/dockerhub/token | \
  docker login -u <user> --password-stdin
```

## Credential Manager CLI

### Installation
```bash
# Credential manager installed by default at /usr/local/bin/nubifer-creds
nubifer-creds --help
```

### Basic Commands

#### List Credentials
```bash
# List all credentials in the active workspace
nubifer-creds list

# List by type
nubifer-creds list -t aws
nubifer-creds list -t api

# List a different workspace (list always shows one workspace at a time)
NUBIFER_WORKSPACE_ID=<workspace-id> nubifer-creds list
```

#### Add Credentials
```bash
# Interactive mode (recommended — secrets prompted with hidden input)
nubifer-creds add -t aws -n production

# -t/--type and -n/--name are required; useful extras:
#   -w <workspace-id>   target a non-active workspace
#   -y                  skip the workspace confirmation prompt
#   --no-sts            AWS only: disable STS token mode
#   --sts-duration <s>  AWS only: token lifetime (default 3600)

# Non-interactive mode (avoid on shared machines — shell history)
nubifer-creds add -t aws -n prod --access-key-id ... --secret-access-key ...
```

#### Update Credentials

There is no `update` command — replace a credential by removing and re-adding it:

```bash
nubifer-creds remove cloud/aws/production
nubifer-creds add -t aws -n production   # enter the new values
```

This is also the local half of rotation — see [Credential Rotation](#credential-rotation) below.

#### Remove Credentials
```bash
# Remove a credential (the path is what `nubifer-creds list` shows)
nubifer-creds remove cloud/aws/production
nubifer-creds remove api/github

# Remove all credentials for a workspace (direct pass operation)
pass rm -rf nubifer/<workspace-id>
```

#### Backup (Encrypted)
```bash
# Export your GPG private key (without it, the store is unreadable)
nubifer-setup-wizard backup
# writes ~/gpg-private-key-backup-YYYYMMDD.asc (chmod 600)

# Version the store itself with git (contents stay GPG-encrypted)
pass git init
pass git remote add origin <private-repo-url>
pass git push -u origin main
```

Recovery on a fresh machine: `gpg --import` the key backup, restore `~/.password-store`, and `nubifer-creds list` works again.

### Advanced Commands

#### Credential Rotation

Automatic rotation is **not implemented** (it's on the roadmap). Rotation is a manual, provider-first procedure:

1. Create the new access key / client secret / service account key in the cloud console
2. Replace the stored values:
   ```bash
   nubifer-creds remove cloud/aws/production
   nubifer-creds add -t aws -n production   # enter the new keys
   ```
3. If token mode is on, clear the cache so nothing stale is served:
   ```bash
   nubifer-creds token clear -t aws -n production
   ```
4. Verify (`aws sts get-caller-identity`), then **deactivate and delete the old key in the cloud console**. Rotation isn't done until the old credential is dead server-side.

Do this per workspace — each workspace's credentials are independent copies. See the [Credential Setup Guide](guides/CREDENTIAL_SETUP.md#rotating-credentials) for the same procedure in context, and [Security Best Practices](guides/SECURITY_BEST_PRACTICES.md) for the rotation cadence.

#### Audit Logging

Every add, access, and removal is appended to `~/.config/nubifer/audit.log` automatically:

```bash
# View credential access log
cat ~/.config/nubifer/audit.log

# View usage of a specific credential
grep 'cloud/aws/production' ~/.config/nubifer/audit.log

# Watch live
tail -f ~/.config/nubifer/audit.log
```

Each entry records timestamp, user, workspace, action, and path — never the secret values.

#### Temporary Credentials
```bash
# Inspect the cached STS token
nubifer-creds token status -t aws -n production

# Force-mint a new token now
nubifer-creds token refresh -t aws -n production

# Shorten the token lifetime (a stolen token is useful for less time)
nubifer-creds token enable -t aws -n production --duration 900
```

For role assumption with MFA, use the AWS CLI directly (`aws sts assume-role --serial-number ... --token-code ...`); the returned session credentials auto-expire.

## Password Manager Integration

There is **no built-in Bitwarden/1Password/KeePassXC integration** in `nubifer-creds`. The store is standard `pass`, however, so the pass ecosystem tooling works directly on it, and you can run any password manager's CLI alongside NubiferOS and copy values in explicitly:

```bash
# Example: pull a secret from Bitwarden into the NubiferOS store
nubifer-creds add -t api -n github --token "$(bw get password github-token)"

# Example: from 1Password
nubifer-creds add -t api -n github --token "$(op read 'op://Cloud/github/token')"
```

**Trade-off to keep in mind**: your external password manager becomes a second copy of the secret. Rotate and revoke in both places, and never enable any sync that would write plaintext to disk.

## Workspace-Based Credential Isolation

### Credential Scoping

Credentials are scoped to workspaces for isolation:

```bash
# Create a workspace
nubifer-workspace create \
  -n "AWS Production" \
  -p aws \
  -a 123456789012 \
  -r us-east-1

# Switch workspace (its credentials become the active set)
nubifer-workspace switch <workspace-id>

# Add credentials inside the workspace
nubifer-creds add -t aws -n default

# Credentials from other workspaces not accessible
# Prevents accidental cross-account operations
```

### Credential Inheritance

Workspaces do **not** inherit or share credentials — this is a deliberate design choice. Each workspace holds independent copies; to use the same account from two workspaces, add the credential to each explicitly (the `-w <workspace-id>` flag targets a non-active workspace).

## Security Best Practices

### 1. Use Short-Lived Credentials

✅ **Recommended**:
- AWS SSO with temporary credentials
- Azure device code flow
- GCP user authentication
- STS token mode (the NubiferOS default for stored AWS keys)

❌ **Avoid**:
- Long-lived IAM access keys
- Service principal secrets without rotation
- Permanent service account keys

### 2. Enable MFA

MFA enforcement lives at the cloud provider, not in `nubifer-creds`:

- Require MFA in your IAM policies / Azure Conditional Access / Google Workspace settings
- Protect the local store with a **passphrase-protected GPG key** — the setup wizard's default key has no passphrase; see the [GPG Setup Guide](guides/GPG_SETUP_GUIDE.md) to set one up

### 3. Credential Rotation

- Rotate static cloud keys on a schedule — **every 90 days** is the recommended baseline (see [Security Best Practices](guides/SECURITY_BEST_PRACTICES.md))
- There are no automatic rotation reminders yet — put it on your calendar
- Follow the manual procedure in [Credential Rotation](#credential-rotation) above

### 4. Audit Logging

Audit logging is always on — every credential operation is appended to `~/.config/nubifer/audit.log` (timestamp, user, workspace, operation, path). Review it monthly:

```bash
less ~/.config/nubifer/audit.log
```

### 5. Least Privilege

```bash
# Use role-based access
# Assign minimal required permissions
# Regularly review and revoke unused credentials
```

### 6. Secure Backup

```bash
# Export the GPG private key (the single point of recovery)
nubifer-setup-wizard backup

# Push the (already-encrypted) store to a private git remote
pass git push
```

Store the key backup securely (encrypted USB, offline storage). Never commit it or sync it to plain cloud storage.

## Environment Variable Management

### Secrets Stay Out of the Environment

NubiferOS deliberately avoids injecting secrets into environment variables — they leak into shell history, process listings, and child processes. Instead:

- **AWS**: credentials flow through `credential_process` (`nubifer-aws-credential-helper`) — no `AWS_ACCESS_KEY_ID` in your environment
- **Workspace context**: non-secret variables (workspace ID/name, region, account) come from the workspace environment (`nubifer-workspace env <workspace-id>` prints them)

### Manual Override

```bash
# Select a non-default AWS credential set for the wrapper
export NUBIFER_AWS_CREDENTIAL=<credential-name>

# If a tool truly requires secrets in its environment, scope them to a
# single command and treat the shell as compromised afterwards:
AWS_ACCESS_KEY_ID=$(nubifer-creds get -t aws -n prod --json | python3 -c 'import json,sys; print(json.load(sys.stdin)["access_key_id"])') some-tool
```

## Credential Vault Architecture

### Storage Location

```
~/.password-store/
└── nubifer/<workspace-id>/...   # GPG-encrypted .gpg files (see hierarchy above)

~/.config/nubifer/audit.log      # Audit log (metadata only, no secret values)
```

### Encryption Details

- **Tooling**: `pass` + GnuPG — battle-tested, audited, no custom cryptography
- **Per-Credential Encryption**: Each credential is a separate GPG-encrypted file
- **Key**: Your personal GPG key (RSA 4096-bit when generated by the setup wizard)
- **Not encrypted**: The directory structure — workspace IDs, provider names, and credential names are visible to anyone with file access (the values are not)

### Access Control

Unlocking is controlled by the GPG agent (and your key's passphrase, if set):

```bash
# Extend passphrase caching
echo "default-cache-ttl 3600" >> ~/.gnupg/gpg-agent.conf
echo "max-cache-ttl 7200" >> ~/.gnupg/gpg-agent.conf

# "Lock" now — drop the agent's cached passphrase
gpgconf --kill gpg-agent
```

## Troubleshooting

### Credentials Not Working

```bash
# Verify credentials exist in the workspace you think you're in
nubifer-creds list

# View a credential (masked display; --json for full values)
nubifer-creds get -t aws -n production

# Check STS token state
nubifer-creds token status -t aws -n production

# Test AWS end-to-end
aws sts get-caller-identity
```

Common cause: credentials added with no active workspace land in the workspace named `default`, not your current one.

### Vault Locked / GPG Prompts Hanging

```bash
# Point pinentry at your terminal, then reset the agent
export GPG_TTY=$(tty)
gpgconf --kill gpg-agent
```

If you've lost the GPG key passphrase, restore the key from your `nubifer-setup-wizard backup` export — there is no separate vault recovery key.

### Credential Rotation Failed

Rotation is manual, which makes rollback simple: the old key keeps working at the provider until you deactivate it.

```bash
# If the new key fails verification, put the old values back
nubifer-creds remove cloud/aws/production
nubifer-creds add -t aws -n production   # re-enter the OLD keys
nubifer-creds token clear -t aws -n production
```

Never deactivate the old provider-side key before `aws sts get-caller-identity` succeeds with the new one.

## Migration from Existing Setups

There is no automatic importer yet — migration is manual, but short:

### From AWS CLI Configuration

```bash
# Read your existing keys, re-enter them, then destroy the plaintext
cat ~/.aws/credentials
nubifer-creds add -t aws -n production
shred -u ~/.aws/credentials
```

### From Azure CLI

```bash
# User accounts: just re-authenticate (az manages its own token cache)
az login

# Service principals: re-add the secret encrypted
nubifer-creds add -t azure -n automation
```

### From GCP

```bash
# ADC / user accounts: re-authenticate
gcloud auth application-default login

# Service account keys: import the JSON key file
nubifer-creds add -t gcp -n my-project --key-file key.json
# (the plaintext key file is securely deleted after import)
```

### From Environment Variables

```bash
# Re-enter each secret via `nubifer-creds add`, then clear the environment
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
history -c   # and scrub any shell history files that captured them
```

## API & SDK Integration

There are no language SDKs yet. For programmatic access, shell out to the CLI and treat the output as a secret:

### Python

```python
import json, subprocess

creds = json.loads(subprocess.check_output(
    ["nubifer-creds", "get", "-t", "aws", "-n", "production", "--json"]
))
print(creds["access_key_id"])
```

### Shell

```bash
# Any stored value, by path
pass show nubifer/<workspace-id>/api/github/token
```

Prefer letting the wrappers do the work (the AWS CLI/SDK picks up credentials via `credential_process` automatically) over pulling raw secrets into your own code.

## Support

### Documentation
- [Credential Setup Guide](guides/CREDENTIAL_SETUP.md)
- [Security Best Practices](guides/SECURITY_BEST_PRACTICES.md)
- [GPG Setup Guide](guides/GPG_SETUP_GUIDE.md)
- [Workspace Management](guides/WORKSPACE_MANAGEMENT.md)

### Troubleshooting
- GitHub Issues: https://github.com/nubiferos/nubiferos/issues
- Discord: https://discord.gg/nubiferos

---

**NubiferOS Version**: 1.0 (Nimbus)  
**Last Updated**: 2026-07-18
