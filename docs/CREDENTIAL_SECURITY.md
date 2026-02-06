# NubiferOS Credential & Secrets Management

## Overview

NubiferOS provides a comprehensive, secure credential management system for cloud accounts, API keys, database credentials, and other secrets. The system integrates with all cloud CLIs, SDKs, and development tools while maintaining security best practices.

## Security Architecture

### Multi-Layer Security

1. **System Keyring** - OS-level secure storage (libsecret/GNOME Keyring)
2. **Encrypted Vault** - AES-256-GCM encrypted credential vault
3. **LUKS Encryption** - Full disk encryption
4. **Workspace Isolation** - Credentials isolated per workspace
5. **Temporary Credentials** - Support for short-lived tokens

### Credential Storage Hierarchy

```
System Keyring (libsecret)
  └── Master Key (encrypted)
      └── Credential Vault (AES-256-GCM)
          ├── Cloud Provider Credentials
          │   ├── AWS (access keys, profiles, SSO)
          │   ├── Azure (service principals, managed identities)
          │   └── GCP (service accounts, ADC)
          ├── API Keys
          │   ├── GitHub/GitLab tokens
          │   ├── Monitoring services (Datadog, New Relic)
          │   └── Third-party APIs
          ├── Database Credentials
          │   ├── PostgreSQL, MySQL, MongoDB
          │   └── Cloud databases (RDS, Cosmos DB)
          ├── SSH Keys
          │   ├── Private keys (encrypted)
          │   └── Key passphrases
          └── Certificates
              ├── TLS/SSL certificates
              └── Client certificates
```

## Credential Types & Best Practices

### 1. AWS Credentials

#### Recommended Approach: AWS SSO (Best)
```bash
# Configure AWS SSO
nubifer-creds aws configure-sso \
  --sso-start-url https://my-company.awsapps.com/start \
  --sso-region us-east-1 \
  --account-id 123456789012 \
  --role-name DevRole

# Login via SSO (opens browser)
nubifer-creds aws sso-login --profile production
```

**Benefits**:
- No long-lived credentials
- Centralized access management
- MFA enforced
- Automatic credential rotation

#### Alternative: IAM Access Keys (Secured)
```bash
# Add AWS access keys (encrypted in vault)
nubifer-creds aws add-access-key \
  --profile production \
  --access-key-id AKIA... \
  --secret-access-key <secret>

# Keys are encrypted and stored in vault
# Automatically injected into AWS CLI/SDK
```

**Security Measures**:
- Keys encrypted with AES-256-GCM
- Master key stored in system keyring
- Keys never written to disk unencrypted
- Automatic rotation reminders
- Audit logging of key usage

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

#### Manual STS Operations
```bash
# Assume a specific role
nubifer-creds aws assume-role \
  --role-arn arn:aws:iam::123456789012:role/DevRole \
  --session-name dev-session \
  --duration 3600

# Temporary credentials auto-expire
# No long-lived keys on disk
```

### 2. Azure Credentials

#### Recommended Approach: Azure CLI with Device Code Flow
```bash
# Login with device code (MFA supported)
nubifer-creds azure login --use-device-code

# Or use service principal (for automation)
nubifer-creds azure add-service-principal \
  --tenant-id <tenant-id> \
  --client-id <client-id> \
  --client-secret <secret>
```

#### Managed Identity (for Azure VMs)
```bash
# Enable managed identity support
nubifer-creds azure enable-managed-identity

# Automatically uses VM's managed identity
# No credentials needed
```

### 3. GCP Credentials

#### Recommended Approach: Application Default Credentials (ADC)
```bash
# Login with user account
nubifer-creds gcp login

# Or use service account key (encrypted)
nubifer-creds gcp add-service-account \
  --key-file service-account.json \
  --project my-project

# Key file encrypted and stored in vault
# Original file securely deleted
```

#### Workload Identity (for GKE)
```bash
# Enable workload identity
nubifer-creds gcp enable-workload-identity

# Automatically uses pod's service account
```

### 4. API Keys & Tokens

#### GitHub/GitLab Personal Access Tokens
```bash
# Add GitHub token (encrypted)
nubifer-creds api add-token \
  --service github \
  --token ghp_... \
  --scopes "repo,workflow"

# Add GitLab token
nubifer-creds api add-token \
  --service gitlab \
  --token glpat-... \
  --scopes "api,read_repository"

# Tokens automatically used by gh/glab CLI
```

#### Monitoring & Observability
```bash
# Datadog API key
nubifer-creds api add-token \
  --service datadog \
  --api-key <key> \
  --app-key <app-key>

# New Relic license key
nubifer-creds api add-token \
  --service newrelic \
  --license-key <key>

# Automatically injected into monitoring agents
```

#### Container Registries
```bash
# Docker Hub
nubifer-creds registry add \
  --registry docker.io \
  --username <user> \
  --password <pass>

# Private registry
nubifer-creds registry add \
  --registry registry.company.com \
  --username <user> \
  --password <pass>

# Automatically used by docker/podman
```

### 5. Database Credentials

```bash
# PostgreSQL
nubifer-creds db add \
  --type postgresql \
  --host db.example.com \
  --port 5432 \
  --database mydb \
  --username dbuser \
  --password <password>

# MongoDB
nubifer-creds db add \
  --type mongodb \
  --connection-string "mongodb://user:pass@host:27017/db"

# Credentials available to database clients
# Connection strings auto-generated
```

### 6. SSH Keys

```bash
# Add SSH key with passphrase
nubifer-creds ssh add-key \
  --name github \
  --key-file ~/.ssh/id_rsa \
  --passphrase <passphrase>

# Passphrase stored encrypted
# SSH agent integration
# Automatic key loading
```

## Integration with CLIs & SDKs

### Automatic Credential Injection

NubiferOS automatically injects credentials into:

#### AWS CLI/SDK
```bash
# Credentials automatically available
aws s3 ls  # Uses credentials from current workspace

# Behind the scenes:
# - Reads from credential vault
# - Injects into AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY
# - Or uses AWS SSO session
# - Respects AWS_PROFILE environment variable
```

#### Azure CLI/SDK
```bash
# Credentials automatically available
az vm list  # Uses credentials from current workspace

# Behind the scenes:
# - Uses Azure CLI token cache (encrypted)
# - Or injects service principal credentials
# - Or uses managed identity
```

#### GCP CLI/SDK
```bash
# Credentials automatically available
gcloud compute instances list

# Behind the scenes:
# - Uses Application Default Credentials
# - Or injects service account key
# - Or uses workload identity
```

#### Terraform
```bash
# Credentials automatically available
terraform plan

# Behind the scenes:
# - AWS: Uses AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY
# - Azure: Uses ARM_CLIENT_ID/ARM_CLIENT_SECRET
# - GCP: Uses GOOGLE_APPLICATION_CREDENTIALS
```

#### Docker/Podman
```bash
# Registry credentials automatically available
docker pull registry.company.com/image

# Behind the scenes:
# - Reads from credential vault
# - Injects into ~/.docker/config.json (encrypted)
# - Automatic login to registries
```

## Credential Manager CLI

### Installation
```bash
# Credential manager installed by default
nubifer-creds --version
```

### Basic Commands

#### List Credentials
```bash
# List all credentials
nubifer-creds list

# List by type
nubifer-creds list --type aws
nubifer-creds list --type api
nubifer-creds list --type db

# List by workspace
nubifer-creds list --workspace production
```

#### Add Credentials
```bash
# Interactive mode (recommended)
nubifer-creds add

# Prompts for:
# - Credential type (AWS, Azure, GCP, API, DB, SSH)
# - Required fields
# - Workspace assignment
# - Expiration (optional)

# Non-interactive mode
nubifer-creds add --type aws --profile prod --access-key-id ... --secret-access-key ...
```

#### Update Credentials
```bash
# Update existing credential
nubifer-creds update --id <credential-id> --secret-access-key <new-key>

# Rotate credentials
nubifer-creds rotate --id <credential-id>
```

#### Remove Credentials
```bash
# Remove credential
nubifer-creds remove --id <credential-id>

# Remove all credentials for workspace
nubifer-creds remove --workspace production --confirm
```

#### Export/Import (Encrypted)
```bash
# Export credentials (encrypted backup)
nubifer-creds export --output backup.enc --password <password>

# Import credentials
nubifer-creds import --input backup.enc --password <password>
```

### Advanced Commands

#### Credential Rotation
```bash
# Check for credentials needing rotation
nubifer-creds check-rotation

# Rotate AWS access keys
nubifer-creds rotate aws --profile production

# Automatic rotation (creates new key, updates vault, deletes old key)
```

#### Audit Logging
```bash
# View credential access log
nubifer-creds audit-log

# View specific credential usage
nubifer-creds audit-log --id <credential-id>

# Export audit log
nubifer-creds audit-log --export audit.log
```

#### Temporary Credentials
```bash
# Generate temporary AWS credentials
nubifer-creds aws get-session-token --duration 3600

# Assume role with MFA
nubifer-creds aws assume-role \
  --role-arn arn:aws:iam::123456789012:role/DevRole \
  --mfa-serial arn:aws:iam::123456789012:mfa/user \
  --mfa-token 123456
```

## Password Manager Integration

### Bitwarden Integration (Recommended)

NubiferOS integrates with Bitwarden for additional credential management:

```bash
# Install Bitwarden CLI
nubifer-creds install-bitwarden

# Login to Bitwarden
bw login

# Sync credentials from Bitwarden
nubifer-creds bitwarden sync

# Import specific credentials
nubifer-creds bitwarden import --item-id <id>

# Two-way sync
nubifer-creds bitwarden enable-sync
```

**Benefits**:
- Centralized credential management
- Cross-device synchronization
- Browser extension integration
- Secure sharing with team members
- Audit logging

### 1Password Integration

```bash
# Install 1Password CLI
nubifer-creds install-1password

# Connect to 1Password
op signin

# Import credentials
nubifer-creds 1password import --vault "Cloud Credentials"
```

### KeePassXC Integration

```bash
# Import from KeePassXC database
nubifer-creds keepassxc import --database ~/credentials.kdbx
```

## Workspace-Based Credential Isolation

### Credential Scoping

Credentials are scoped to workspaces for isolation:

```bash
# Create workspace with credentials
nubifer-workspace create \
  --name "AWS Production" \
  --provider aws \
  --credentials prod-aws-creds

# Switch workspace (credentials automatically loaded)
nubifer-workspace switch aws-production

# Credentials from other workspaces not accessible
# Prevents accidental cross-account operations
```

### Credential Inheritance

```bash
# Create workspace with inherited credentials
nubifer-workspace create \
  --name "AWS Dev" \
  --inherit-from aws-production \
  --override-credentials dev-aws-creds

# Inherits non-sensitive settings
# Uses separate credentials
```

## Security Best Practices

### 1. Use Short-Lived Credentials

✅ **Recommended**:
- AWS SSO with temporary credentials
- Azure device code flow
- GCP user authentication
- STS assume role with MFA

❌ **Avoid**:
- Long-lived IAM access keys
- Service principal secrets without rotation
- Permanent service account keys

### 2. Enable MFA

```bash
# Require MFA for credential access
nubifer-creds config set require-mfa true

# Configure MFA device
nubifer-creds mfa setup

# MFA required for sensitive operations
```

### 3. Credential Rotation

```bash
# Set rotation policy
nubifer-creds config set rotation-days 90

# Enable automatic rotation reminders
nubifer-creds config set rotation-reminders true

# Rotate credentials
nubifer-creds rotate --all
```

### 4. Audit Logging

```bash
# Enable comprehensive audit logging
nubifer-creds config set audit-logging true

# Log all credential access
# Includes: timestamp, user, workspace, operation
```

### 5. Least Privilege

```bash
# Use role-based access
# Assign minimal required permissions
# Regularly review and revoke unused credentials
```

### 6. Secure Backup

```bash
# Encrypted backup
nubifer-creds backup create \
  --output ~/backups/credentials-$(date +%Y%m%d).enc \
  --password <strong-password>

# Store backup securely (encrypted USB, cloud storage with encryption)
```

## Environment Variable Management

### Automatic Injection

Credentials are automatically injected as environment variables:

```bash
# AWS
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_SESSION_TOKEN=...  # For temporary credentials
export AWS_REGION=...

# Azure
export ARM_CLIENT_ID=...
export ARM_CLIENT_SECRET=...
export ARM_TENANT_ID=...
export ARM_SUBSCRIPTION_ID=...

# GCP
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json
export GOOGLE_CLOUD_PROJECT=...

# Custom API keys
export GITHUB_TOKEN=...
export GITLAB_TOKEN=...
export DATADOG_API_KEY=...
```

### Manual Override

```bash
# Temporarily override credentials
nubifer-creds env set AWS_PROFILE=development

# Run command with specific credentials
nubifer-creds exec --profile production -- aws s3 ls

# Clear environment
nubifer-creds env clear
```

## Credential Vault Architecture

### Storage Location

```
~/.nubifer/vault/
├── master.key          # Master key (encrypted by system keyring)
├── credentials.db      # Encrypted credential database
├── audit.log           # Audit log (encrypted)
└── config.json         # Vault configuration
```

### Encryption Details

- **Algorithm**: AES-256-GCM
- **Key Derivation**: PBKDF2 with 100,000 iterations
- **Master Key**: Stored in system keyring (libsecret)
- **Per-Credential Encryption**: Each credential encrypted separately
- **Metadata**: Encrypted separately from credential data

### Access Control

```bash
# Set vault password
nubifer-creds vault set-password

# Lock vault (requires password to unlock)
nubifer-creds vault lock

# Unlock vault
nubifer-creds vault unlock

# Auto-lock after inactivity
nubifer-creds config set auto-lock-minutes 15
```

## Troubleshooting

### Credentials Not Working

```bash
# Verify credentials are loaded
nubifer-creds verify

# Check environment variables
nubifer-creds env show

# Test AWS credentials
nubifer-creds test aws

# View credential details (without secrets)
nubifer-creds show --id <credential-id>
```

### Vault Locked

```bash
# Unlock vault
nubifer-creds vault unlock

# Reset vault password (requires recovery key)
nubifer-creds vault reset-password --recovery-key <key>
```

### Credential Rotation Failed

```bash
# Check rotation status
nubifer-creds rotation-status

# Manually rotate
nubifer-creds rotate --id <credential-id> --force

# Rollback rotation
nubifer-creds rotate rollback --id <credential-id>
```

## Migration from Existing Setups

### From AWS CLI Configuration

```bash
# Import existing AWS profiles
nubifer-creds import aws-cli

# Imports from ~/.aws/credentials and ~/.aws/config
# Original files backed up and encrypted
```

### From Azure CLI

```bash
# Import Azure credentials
nubifer-creds import azure-cli

# Imports from ~/.azure/
```

### From GCP

```bash
# Import GCP credentials
nubifer-creds import gcloud

# Imports from ~/.config/gcloud/
```

### From Environment Variables

```bash
# Import from current environment
nubifer-creds import env

# Prompts for which variables to import
# Clears original environment variables
```

## API & SDK Integration

### Python SDK

```python
from nubifer import credentials

# Get AWS credentials
aws_creds = credentials.get('aws', profile='production')
print(aws_creds.access_key_id)

# Get API token
github_token = credentials.get_token('github')

# Use with boto3
import boto3
session = credentials.get_aws_session('production')
s3 = session.client('s3')
```

### Go SDK

```go
import "github.com/nubiferos/nubifer-go/credentials"

// Get AWS credentials
creds, err := credentials.GetAWS("production")

// Get API token
token, err := credentials.GetToken("github")
```

### Node.js SDK

```javascript
const { credentials } = require('@nubiferos/nubifer');

// Get AWS credentials
const awsCreds = await credentials.getAWS('production');

// Get API token
const githubToken = await credentials.getToken('github');
```

## Support

### Documentation
- [Credential Manager CLI Reference](CREDENTIAL_CLI.md)
- [API Documentation](CREDENTIAL_API.md)
- [Security Architecture](SECURITY_ARCHITECTURE.md)

### Troubleshooting
- [Common Issues](TROUBLESHOOTING.md#credentials)
- GitHub Issues: https://github.com/nubiferos/nubiferos/issues
- Discord: https://discord.gg/nubiferos

---

**NubiferOS Version**: 1.0 (Nimbus)  
**Last Updated**: 2024-01-15
