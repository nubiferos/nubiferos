# NubiferOS Workspace Manager

Secure cloud workspace isolation with visual context indicators to prevent accidental cross-account operations.

## Features

- **Visual Context Indicators**: Color-coded terminal prompts showing provider, account, and region
- **Workspace Isolation**: Separate environment variables and credentials per workspace
- **Read-Only Mode**: Prevent accidental modifications with visual lock indicator
- **Security-First**: Audit logging, secure file permissions, credential isolation
- **Multi-Cloud**: Support for AWS, Azure, GCP, and multi-cloud workspaces
- **Easy Switching**: Quick workspace switching with visual confirmation

## Color Scheme

Each cloud provider has a distinct color for instant visual recognition:

- **AWS**: 🟠 Orange (#FF9900)
- **Azure**: 🔵 Blue (#0078D4)
- **GCP**: 🔵🔴🟡🟢 Google's 4-color logo (#4285F4 primary)
- **Oracle Cloud**: 🔴 Red (#FF0000)
- **Multi-Cloud**: 🟣 Purple (#6B46C1)

## Installation

```bash
sudo ./install.sh
```

This installs:
- `nubifer-workspace` command to `/usr/local/bin/`
- Shell integration to `/etc/nubifer/shell-integration.sh`
- System-wide bash integration in `/etc/bash.bashrc`

## Quick Start

### 1. Create a Workspace

```bash
# AWS workspace
nubifer-workspace create \
  --name "AWS Production" \
  --provider aws \
  --account-id 123456789012 \
  --account-name "prod-account" \
  --region us-east-1

# Azure workspace
nubifer-workspace create \
  --name "Azure Dev" \
  --provider azure \
  --account-id "subscription-id" \
  --account-name "dev-subscription" \
  --region eastus

# GCP workspace
nubifer-workspace create \
  --name "GCP Staging" \
  --provider gcp \
  --account-id "project-id" \
  --account-name "staging-project" \
  --region us-central1

# Read-only workspace (safe browsing)
nubifer-workspace create \
  --name "AWS Prod (Read-Only)" \
  --provider aws \
  --account-id 123456789012 \
  --read-only
```

### 2. List Workspaces

```bash
# List all workspaces
nubifer-workspace list

# Filter by provider
nubifer-workspace list --provider aws
```

### 3. Switch Workspaces

```bash
# Switch by ID
nubifer-workspace switch abc123def456

# Switch by name (case-insensitive)
nubifer-workspace switch "aws production"

# Activate in current shell
eval $(nubifer-workspace env abc123def456)
```

### 4. View Current Workspace

```bash
nubifer-workspace current
```

Output:
```
============================================================
☁️ Workspace: AWS Production
============================================================
Provider:  AWS
Account:   prod-account
Region:    us-east-1
Mode:      🔓 Read-Write
============================================================
```

## Terminal Prompt Integration

When a workspace is active, your terminal prompt shows the context:

```bash
# AWS workspace (orange)
[☁️ prod-account] user@host:~$

# Azure workspace (blue)
[⛅ dev-subscription] user@host:~$

# GCP workspace (red)
[🌩️ staging-project] user@host:~$

# Read-only mode (with lock)
[☁️ prod-account 🔒] user@host:~$
```

## Read-Only Mode

Protect against accidental modifications:

```bash
# Enable read-only mode
nubifer-workspace readonly <workspace-id> --enable

# Disable read-only mode
nubifer-workspace readonly <workspace-id> --disable
```

When read-only mode is active:
- Terminal prompt shows 🔒 lock icon
- Write operations are blocked
- Clear error messages explain why operations are blocked

## Environment Variables

Each workspace sets provider-specific environment variables:

### AWS
```bash
AWS_DEFAULT_REGION=us-east-1
AWS_REGION=us-east-1
AWS_ACCOUNT_ID=123456789012
NUBIFER_WORKSPACE_PROVIDER=aws
NUBIFER_WORKSPACE_ACCOUNT=prod-account
```

### Azure
```bash
AZURE_LOCATION=eastus
AZURE_SUBSCRIPTION_ID=subscription-id
NUBIFER_WORKSPACE_PROVIDER=azure
NUBIFER_WORKSPACE_ACCOUNT=dev-subscription
```

### GCP
```bash
GOOGLE_CLOUD_PROJECT=project-id
GOOGLE_CLOUD_REGION=us-central1
NUBIFER_WORKSPACE_PROVIDER=gcp
NUBIFER_WORKSPACE_ACCOUNT=staging-project
```

## Shell Aliases

Convenient shortcuts:

```bash
nw              # Short for nubifer-workspace
nw-switch       # Quick workspace switching
nw-context      # Show current workspace
nw-activate     # Activate workspace in current shell
```

## Security Features

### Audit Logging

All workspace operations are logged to `~/.config/nubifer/workspace-audit.log`:

```
2025-11-12T10:30:00 | user | CREATE | abc123 | name=AWS Production, provider=aws
2025-11-12T10:31:00 | user | SWITCH | abc123 | name=AWS Production
2025-11-12T10:35:00 | user | SET_READ_ONLY | abc123 | mode=enabled
```

### Secure File Permissions

- Workspace configurations: `0600` (owner read/write only)
- Configuration directory: `0700` (owner access only)
- Audit log: `0600` (owner read/write only)

### Credential Isolation

- Credentials are scoped to workspaces via `NUBIFER_WORKSPACE` environment variable
- Integration with `nubifer-creds` for secure credential storage
- No credential leakage between workspaces

### Read-Only Protection

- Blocks write operations when read-only mode is enabled
- Visual indicators (lock icon) in terminal and UI
- Clear error messages when operations are blocked

## Integration with Cloud CLIs

### AWS CLI

```bash
# Workspace environment variables are automatically used
aws s3 ls  # Uses AWS_REGION and AWS_ACCOUNT_ID from workspace

# Read-only mode blocks writes
aws s3 rm s3://bucket/file  # Blocked if read-only
```

### Azure CLI

```bash
# Uses AZURE_SUBSCRIPTION_ID from workspace
az vm list

# Read-only mode blocks writes
az vm delete --name myvm  # Blocked if read-only
```

### GCP CLI

```bash
# Uses GOOGLE_CLOUD_PROJECT from workspace
gcloud compute instances list

# Read-only mode blocks writes
gcloud compute instances delete myvm  # Blocked if read-only
```

## Advanced Usage

### Update Workspace

```bash
nubifer-workspace update <workspace-id> \
  --name "New Name" \
  --account-name "new-account" \
  --region us-west-2
```

### Delete Workspace

```bash
nubifer-workspace delete <workspace-id>
```

Note: Cannot delete the currently active workspace. Switch to another workspace first.

### Link Credentials

```bash
# Create workspace with credential reference
nubifer-workspace create \
  --name "AWS Prod" \
  --provider aws \
  --account-id 123456789012 \
  --credential-id <cred-id-from-nubifer-creds>
```

## Troubleshooting

### Prompt Not Updating

```bash
# Reload shell integration
source /etc/nubifer/shell-integration.sh

# Or restart your shell
exec bash
```

### Workspace Not Found

```bash
# List all workspaces to find correct ID
nubifer-workspace list

# Check workspace file exists
ls ~/.config/nubifer/workspaces/
```

### Environment Variables Not Set

```bash
# Make sure to eval the output
eval $(nubifer-workspace env <workspace-id>)

# Or use the activate function
nubifer_activate <workspace-id>
```

### Read-Only Mode Not Working

The read-only protection requires CLI wrapper scripts. These will be installed separately as part of the full NubiferOS installation.

## Files and Directories

```
~/.config/nubifer/
├── workspaces/              # Workspace configurations
│   ├── abc123.json         # Workspace config files
│   └── def456.json
├── current-workspace        # Currently active workspace ID
└── workspace-audit.log      # Audit log

/etc/nubifer/
└── shell-integration.sh     # System-wide shell integration

/usr/local/bin/
└── nubifer-workspace        # Main command
```

## Configuration File Format

Workspace configuration (`~/.config/nubifer/workspaces/<id>.json`):

```json
{
  "workspace_id": "abc123def456",
  "name": "AWS Production",
  "provider": "aws",
  "account_id": "123456789012",
  "account_name": "prod-account",
  "region": "us-east-1",
  "credential_id": null,
  "read_only": false,
  "created_at": "2025-11-12T10:30:00",
  "last_used": "2025-11-12T10:35:00",
  "theme": {
    "name": "AWS",
    "color": "#FF9900",
    "terminal_color": "208",
    "icon": "☁️"
  },
  "environment": {
    "AWS_DEFAULT_REGION": "us-east-1",
    "AWS_REGION": "us-east-1",
    "AWS_ACCOUNT_ID": "123456789012",
    "NUBIFER_WORKSPACE_PROVIDER": "aws",
    "NUBIFER_WORKSPACE_ACCOUNT": "prod-account",
    "NUBIFER_WORKSPACE_ACCOUNT_ID": "123456789012"
  }
}
```

## Best Practices

1. **Use Descriptive Names**: Include environment and purpose (e.g., "AWS Production Web", "Azure Dev Database")

2. **Enable Read-Only by Default**: Create workspaces in read-only mode, disable only when needed

3. **One Workspace Per Account**: Don't mix multiple accounts in one workspace

4. **Regular Audits**: Review `workspace-audit.log` for unexpected activity

5. **Visual Confirmation**: Always check terminal prompt before running commands

6. **Separate Production**: Use different workspaces (and ideally different machines) for production

## Integration with Other NubiferOS Components

### Credential Manager

```bash
# Create credentials
nubifer-creds add --type aws --name prod-creds

# Link to workspace
nubifer-workspace create \
  --name "AWS Prod" \
  --provider aws \
  --account-id 123456789012 \
  --credential-id prod-creds
```

### Context Indicator (GNOME Extension)

The GNOME Shell extension reads workspace configuration and displays:
- Provider icon and color
- Account name
- Region
- Read-only status

### Resource Viewer

The Resource Viewer application uses workspace context to:
- Filter resources by active workspace
- Apply read-only restrictions
- Show workspace-specific views

## Contributing

See [CONTRIBUTING.md](../../CONTRIBUTING.md) for development guidelines.

## License

Part of NubiferOS - See main project LICENSE file.

## Support

- Documentation: `/usr/share/doc/nubifer/`
- Issues: GitHub Issues
- Community: NubiferOS Forums
