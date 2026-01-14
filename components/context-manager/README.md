# NubiferOS Context Manager

Workspace management with visual context indicators and environment isolation for cloud accounts.

## Architecture

- **Storage Backend**: SQLite database for workspace metadata
- **D-Bus Interface**: System-wide workspace service
- **Environment Integration**: Automatic environment variable injection
- **Shell Integration**: Visual context in terminal prompts
- **CLI Tool**: `nubifer-workspace` command-line interface

## Features

- ✅ Create and manage cloud workspaces
- ✅ Visual context indicators (provider icons, colors)
- ✅ Environment variable injection per workspace
- ✅ Read-only mode for safe browsing
- ✅ SQLite database for workspace metadata
- ✅ D-Bus interface for system integration
- ✅ Shell integration with custom prompts
- ✅ Support for AWS, Azure, GCP, Oracle, Multi-cloud

## Installation

```bash
cd components/context-manager
sudo ./install.sh
```

## Usage

### Create a Workspace

**AWS:**
```bash
nubifer-workspace create \
  --name "AWS Production" \
  --provider aws \
  --account-id 123456789012 \
  --account-name "Prod Account" \
  --region us-east-1
```

**Azure:**
```bash
nubifer-workspace create \
  --name "Azure Dev" \
  --provider azure \
  --account-id my-subscription-id \
  --account-name "Dev Subscription" \
  --region eastus
```

**GCP:**
```bash
nubifer-workspace create \
  --name "GCP Staging" \
  --provider gcp \
  --account-id my-project-id \
  --account-name "Staging Project" \
  --region us-central1
```

**Read-Only Mode:**
```bash
nubifer-workspace create \
  --name "AWS Prod (Read-Only)" \
  --provider aws \
  --account-id 123456789012 \
  --read-only
```

### List Workspaces

```bash
# List all workspaces
nubifer-workspace list

# List by provider
nubifer-workspace list --provider aws

# JSON output
nubifer-workspace list --format json
```

### Switch Workspace

```bash
# Switch by ID
nubifer-workspace switch abc123def456

# Switch by name
nubifer-workspace switch "AWS Production"

# Activate in current shell
eval $(nubifer-workspace env abc123def456)
```

### Show Current Workspace

```bash
nubifer-workspace current
```

### Delete Workspace

```bash
nubifer-workspace delete abc123def456
```

### Set Read-Only Mode

```bash
# Enable read-only
nubifer-workspace set-readonly abc123def456 true

# Disable read-only
nubifer-workspace set-readonly abc123def456 false
```

### Export Environment Variables

```bash
# Export for specific workspace
nubifer-workspace env abc123def456

# Use in shell
eval $(nubifer-workspace env abc123def456)
```

## Workspace Database

SQLite database at `~/.config/nubiferos/workspaces.db`:

```sql
CREATE TABLE workspaces (
    workspace_id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    provider TEXT NOT NULL,
    account_id TEXT NOT NULL,
    account_name TEXT,
    region TEXT,
    credential_id TEXT,
    read_only INTEGER DEFAULT 0,
    created_at TEXT NOT NULL,
    last_used TEXT,
    theme_json TEXT,
    environment_json TEXT
);
```

## Environment Variables

When a workspace is activated, the following environment variables are exported:

### Common Variables
- `NUBIFEROS_WORKSPACE_ID` - Workspace identifier
- `NUBIFEROS_WORKSPACE_NAME` - Workspace name
- `NUBIFEROS_WORKSPACE_READ_ONLY` - Read-only mode (true/false)
- `NUBIFEROS_PROVIDER` - Cloud provider
- `NUBIFEROS_ACCOUNT` - Account name
- `NUBIFEROS_ACCOUNT_ID` - Account ID

### AWS Variables
- `AWS_DEFAULT_REGION` - Default AWS region
- `AWS_REGION` - AWS region
- `AWS_ACCOUNT_ID` - AWS account ID

### Azure Variables
- `AZURE_LOCATION` - Azure location
- `AZURE_SUBSCRIPTION_ID` - Azure subscription ID

### GCP Variables
- `GOOGLE_CLOUD_PROJECT` - GCP project ID
- `GOOGLE_CLOUD_REGION` - GCP region
- `GCP_PROJECT` - GCP project ID (alias)
- `GCP_REGION` - GCP region (alias)

### Oracle Variables
- `OCI_REGION` - Oracle Cloud region
- `OCI_TENANCY` - Oracle Cloud tenancy

## Shell Integration

The shell integration script (`/etc/profile.d/nubiferos-context.sh`) provides:

### Functions
- `nubifer_activate <workspace-id>` - Activate workspace in current shell
- `nubifer_context` - Show current workspace context

### Aliases
- `nw` - Short for `nubifer-workspace`
- `nw-activate` - Activate workspace
- `nw-context` - Show context
- `nw-switch` - Switch workspace
- `nw-list` - List workspaces
- `nw-current` - Show current workspace

### Custom Prompt

When a workspace is activated, your terminal prompt changes to show:
- Provider icon (☁️ for AWS, ⛅ for Azure, etc.)
- Account name
- Color coding by provider
- Read-only indicator (🔒) if applicable

Example:
```
[☁️ Prod Account] user@host:~$
[⛅ Dev Subscription 🔒] user@host:~$
```

## D-Bus Interface

**Service Name**: `org.nubiferos.ContextManager`  
**Object Path**: `/org/nubiferos/ContextManager`  
**Interface**: `org.nubiferos.ContextManager`

### Methods

- `CreateWorkspace(name, provider, account_id, region, credential_id, read_only) -> workspace_id`
- `SwitchWorkspace(workspace_id) -> success`
- `GetCurrentWorkspace() -> workspace_dict`
- `ListWorkspaces(provider) -> list_of_workspaces`
- `DeleteWorkspace(workspace_id) -> success`
- `SetReadOnly(workspace_id, read_only) -> success`

### Signals

- `WorkspaceSwitched(workspace_id, provider, account_id)` - Emitted when workspace is switched

### Example D-Bus Usage

```python
import dbus

bus = dbus.SessionBus()
service = bus.get_object(
    'org.nubiferos.ContextManager',
    '/org/nubiferos/ContextManager'
)

# Create workspace
workspace_id = service.CreateWorkspace(
    'AWS Production', 'aws', '123456789012', 'us-east-1', '', False,
    dbus_interface='org.nubiferos.ContextManager'
)

# List workspaces
workspaces = service.ListWorkspaces(
    '',  # Empty string for all providers
    dbus_interface='org.nubiferos.ContextManager'
)

# Switch workspace
success = service.SwitchWorkspace(
    workspace_id,
    dbus_interface='org.nubiferos.ContextManager'
)
```

## Integration with Credential Manager

Link workspaces to credentials from `nubifer-creds`:

```bash
# Create credential
nubifer-creds add --provider aws --account-id 123456789012 --account-name prod

# Create workspace with credential
nubifer-workspace create \
  --name "AWS Prod" \
  --provider aws \
  --account-id 123456789012 \
  --credential-id <from-nubifer-creds>
```

## Workflow Example

```bash
# 1. Create workspaces for different accounts
nubifer-workspace create --name "AWS Prod" --provider aws --account-id 111111111111
nubifer-workspace create --name "AWS Dev" --provider aws --account-id 222222222222
nubifer-workspace create --name "Azure Prod" --provider azure --account-id sub-123

# 2. List workspaces
nubifer-workspace list

# 3. Switch to AWS Prod
nubifer-workspace switch "AWS Prod"

# 4. Activate in current shell
eval $(nubifer-workspace env <workspace-id>)

# 5. Verify environment
echo $AWS_ACCOUNT_ID
echo $NUBIFEROS_WORKSPACE_NAME

# 6. Use AWS CLI (automatically uses workspace context)
aws s3 ls

# 7. Switch to different workspace
nubifer-workspace switch "Azure Prod"
eval $(nubifer-workspace env <workspace-id>)

# 8. Use Azure CLI
az vm list
```

## Security Features

- ✅ Workspace isolation via environment variables
- ✅ Read-only mode to prevent accidental changes
- ✅ Visual indicators to prevent confusion
- ✅ Audit logging (workspace switches tracked)
- ✅ Secure file permissions (0o700 for config directory)

## Troubleshooting

### Workspace not found

```
Error: Workspace not found: abc123
```

**Solution**: List workspaces to find correct ID:
```bash
nubifer-workspace list
```

### Environment not activated

If environment variables aren't set after switching:

```bash
# Manually activate
eval $(nubifer-workspace env <workspace-id>)
```

### Shell integration not working

Reload shell integration:
```bash
source /etc/profile.d/nubiferos-context.sh
```

Or start a new shell session.

## Development

### Project Structure

```
components/context-manager/
├── src/
│   ├── workspace_service.py  # Core service logic
│   ├── dbus_interface.py     # D-Bus service
│   ├── environment.py        # Environment export
│   └── cli.py                # CLI tool
├── nubiferos-context.sh      # Shell integration
├── requirements.txt          # Python dependencies
├── install.sh                # Installation script
└── README.md                 # This file
```

### Running Tests

```bash
# Syntax check
python3 -m py_compile src/*.py

# Manual testing
./src/cli.py status
./src/cli.py list
```

## Future Enhancements (Deferred to Beta)

- [ ] Systemd service for D-Bus interface
- [ ] GNOME virtual desktop integration
- [ ] KDE Plasma integration
- [ ] Workspace templates
- [ ] Workspace groups
- [ ] Automatic workspace switching based on directory
- [ ] Workspace sharing/export

## License

Part of NubiferOS - GPL-3.0
