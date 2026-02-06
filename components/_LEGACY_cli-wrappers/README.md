# NubiferOS CLI Wrappers

Secure CLI wrappers that inject credentials and enforce read-only mode for cloud tools.

## Security Rationale

**Problem**: Without wrappers, credentials would be exposed in environment variables, visible to all processes.

**Solution**: Wrappers inject credentials securely at execution time, only for the specific command being run.

## Features

- ✅ Automatic credential injection from active workspace
- ✅ No credential exposure in environment variables
- ✅ Read-only mode enforcement
- ✅ Prevention of accidental destructive operations
- ✅ Seamless integration with existing workflows
- ✅ Support for AWS, Azure, GCP, Terraform, Kubectl

## Architecture

```
User Command: aws ec2 describe-instances
       ↓
/usr/local/bin/aws (wrapper)
       ↓
1. Check active workspace (NUBIFEROS_WORKSPACE_ID)
2. Get workspace via D-Bus (ContextManager)
3. Get credentials via D-Bus (CredentialManager)
4. Check read-only mode
5. Block if write operation in read-only mode
6. Inject credentials into execution environment
7. Execute /usr/bin/aws with credentials
       ↓
AWS CLI runs with credentials
```

## Supported Tools

### AWS CLI (`aws`)
- **Real Binary**: `/usr/bin/aws`
- **Wrapper**: `/usr/local/bin/aws`
- **Credentials**: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY
- **Write Operations Blocked**: create*, delete*, put*, update*, terminate*, stop*, modify*, attach*, detach*, etc.
- **Read Operations Allowed**: describe*, list*, get*, show*

### Azure CLI (`az`)
- **Real Binary**: `/usr/bin/az`
- **Wrapper**: `/usr/local/bin/az`
- **Credentials**: AZURE_CLIENT_ID, AZURE_CLIENT_SECRET, AZURE_TENANT_ID
- **Write Operations Blocked**: create, delete, update, set, add, remove, start, stop, etc.
- **Read Operations Allowed**: show, list, get

### GCloud CLI (`gcloud`)
- **Real Binary**: `/usr/bin/gcloud`
- **Wrapper**: `/usr/local/bin/gcloud`
- **Credentials**: GOOGLE_APPLICATION_CREDENTIALS (temp file)
- **Write Operations Blocked**: create, delete, update, insert, patch, add, remove, etc.
- **Read Operations Allowed**: describe, list, get

### Terraform (`terraform`)
- **Real Binary**: `/usr/bin/terraform`
- **Wrapper**: `/usr/local/bin/terraform`
- **Credentials**: Provider-specific (AWS, Azure, GCP)
- **Write Operations Blocked**: apply, destroy, import, taint, untaint, state
- **Read Operations Allowed**: plan, show, validate, fmt, version, output

### Kubectl (`kubectl`)
- **Real Binary**: `/usr/bin/kubectl`
- **Wrapper**: `/usr/local/bin/kubectl`
- **Credentials**: Cloud provider credentials for managed Kubernetes
- **Write Operations Blocked**: create, delete, apply, patch, replace, scale, etc.
- **Read Operations Allowed**: get, describe, logs, top, explain

## Installation

```bash
cd components/cli-wrappers
sudo ./install-wrappers.sh
```

This installs wrappers to `/usr/local/bin/`, which typically comes before `/usr/bin/` in PATH.

## Usage

### Normal Usage (Automatic)

Once installed, wrappers are used automatically:

```bash
# Activate workspace
eval $(nubifer-workspace env <workspace-id>)

# Use AWS CLI normally - credentials injected automatically
aws ec2 describe-instances

# Use Azure CLI normally
az vm list

# Use GCloud CLI normally
gcloud compute instances list
```

### Read-Only Mode

When workspace is in read-only mode:

```bash
# Set workspace to read-only
nubifer-workspace set-readonly <workspace-id> true

# Activate workspace
eval $(nubifer-workspace env <workspace-id>)

# Read operations work
aws ec2 describe-instances
✓ Success

# Write operations are blocked
aws ec2 terminate-instances --instance-ids i-123456
❌ Operation blocked: Workspace 'AWS Prod' is in READ-ONLY mode.
   Use 'nubifer-workspace set-readonly abc123 false' to enable writes.
```

### Bypassing Wrappers

To use real binaries directly (not recommended):

```bash
/usr/bin/aws ec2 describe-instances
/usr/bin/az vm list
/usr/bin/gcloud compute instances list
```

## Read-Only Mode Enforcement

### AWS CLI

**Blocked Operations**:
- create*, delete*, put*, update*, terminate*, stop*, modify*
- attach*, detach*, start*, reboot*, run*, launch*
- associate*, disassociate*, enable*, disable*
- register*, deregister*, allocate*, release*
- revoke*, authorize*, import*, export*, copy*
- restore*, reset*, cancel*, purchase*, accept*, reject*

**Allowed Operations**:
- describe*, list*, get*, show*

### Azure CLI

**Blocked Operations**:
- create, delete, update, set, add, remove
- start, stop, restart, deallocate, apply
- attach, detach, enable, disable
- register, unregister, lock, unlock
- move, restore, reset, revoke, grant, assign

**Allowed Operations**:
- show, list, get

### GCloud CLI

**Blocked Operations**:
- create, delete, update, insert, patch
- add, remove, start, stop, reset, restart
- set, unset, enable, disable
- attach, detach, move, restore
- import, export, deploy, cancel, revoke, grant

**Allowed Operations**:
- describe, list, get

### Terraform

**Blocked Operations**:
- apply, destroy, import, taint, untaint, state

**Allowed Operations**:
- plan, show, validate, fmt, version, output, graph, providers, console, refresh

### Kubectl

**Blocked Operations**:
- create, delete, apply, patch, replace
- scale, autoscale, expose, run, set
- label, annotate, taint, drain, cordon, uncordon
- rollout, edit, attach, exec, port-forward, proxy, cp, auth

**Allowed Operations**:
- get, describe, logs, top, explain
- api-resources, api-versions, cluster-info, version, config

## Error Messages

### No Active Workspace

```
⚠ No active workspace. Activate one with:
  nubifer-workspace list
  eval $(nubifer-workspace env <workspace-id>)
```

### Read-Only Mode Blocked

```
❌ Operation blocked: Workspace 'AWS Production' is in READ-ONLY mode.
   Use 'nubifer-workspace set-readonly abc123def456 false' to enable writes.
```

### No Credentials

If workspace has no credentials configured, the wrapper will still execute but the cloud CLI may fail with authentication errors.

## Security Features

✅ **No Environment Variable Exposure**: Credentials injected only for specific command execution  
✅ **Read-Only Enforcement**: Prevents accidental destructive operations  
✅ **Workspace Isolation**: Each workspace has separate credentials  
✅ **D-Bus Integration**: Secure credential retrieval  
✅ **Temporary Files**: GCP keys written to temp files with 0600 permissions  
✅ **Automatic Cleanup**: Temp files cleaned up after execution  

## Testing

### Test Read Operations (Should Work)

```bash
# Activate workspace
eval $(nubifer-workspace env <workspace-id>)

# Test AWS
aws ec2 describe-instances
aws s3 ls

# Test Azure
az vm list
az group list

# Test GCP
gcloud compute instances list
gcloud projects list

# Test Terraform
terraform plan
terraform show

# Test Kubectl
kubectl get pods
kubectl describe nodes
```

### Test Write Operations (Should Block in Read-Only)

```bash
# Set workspace to read-only
nubifer-workspace set-readonly <workspace-id> true
eval $(nubifer-workspace env <workspace-id>)

# These should be blocked
aws ec2 terminate-instances --instance-ids i-123456
az vm delete --name myvm --resource-group myrg
gcloud compute instances delete myinstance
terraform apply
kubectl delete pod mypod
```

### Test Write Operations (Should Work in Read-Write)

```bash
# Set workspace to read-write
nubifer-workspace set-readonly <workspace-id> false
eval $(nubifer-workspace env <workspace-id>)

# These should work (but be careful!)
aws ec2 describe-instances  # Still works
aws ec2 create-tags --resources i-123456 --tags Key=Test,Value=Value
```

## Troubleshooting

### Wrapper Not Found

```
bash: aws: command not found
```

**Solution**: Check PATH and installation:
```bash
which aws
# Should show: /usr/local/bin/aws

echo $PATH
# Should have /usr/local/bin before /usr/bin
```

### D-Bus Connection Failed

```
✗ Error: D-Bus error: ...
```

**Solution**: Ensure services are running:
```bash
# Check if services are available
dbus-send --session --print-reply \
  --dest=org.nubiferos.ContextManager \
  /org/nubiferos/ContextManager \
  org.freedesktop.DBus.Introspectable.Introspect
```

### Real Binary Not Found

```
✗ Error: Real binary not found: /usr/bin/aws
```

**Solution**: Install the real CLI tool:
```bash
# AWS CLI
sudo apt-get install awscli

# Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# GCloud CLI
# Follow: https://cloud.google.com/sdk/docs/install
```

## Development

### Project Structure

```
components/cli-wrappers/
├── wrapper_base.py          # Base wrapper class
├── aws-wrapper.py           # AWS CLI wrapper
├── az-wrapper.py            # Azure CLI wrapper
├── gcloud-wrapper.py        # GCloud CLI wrapper
├── terraform-wrapper.py     # Terraform wrapper
├── kubectl-wrapper.py       # Kubectl wrapper
├── install-wrappers.sh      # Installation script
└── README.md                # This file
```

### Adding New Wrappers

1. Create new wrapper file (e.g., `docker-wrapper.py`)
2. Extend `CLIWrapperBase`
3. Implement `is_write_operation()` and `inject_credentials()`
4. Add to `install-wrappers.sh`

Example:
```python
from wrapper_base import CLIWrapperBase

class DockerWrapper(CLIWrapperBase):
    WRITE_OPERATIONS = {'run', 'create', 'start', 'stop', 'rm', 'rmi'}
    
    def __init__(self):
        super().__init__('docker', '/usr/bin/docker')
    
    def is_write_operation(self, args: list) -> bool:
        if not args:
            return False
        return args[0].lower() in self.WRITE_OPERATIONS
    
    def inject_credentials(self, credentials: dict, env: dict) -> dict:
        # Docker-specific credential injection
        return env
```

## Future Enhancements

- [ ] Confirmation prompts for destructive operations
- [ ] Audit logging of all commands
- [ ] Rate limiting for API calls
- [ ] Cost estimation before execution
- [ ] Dry-run mode
- [ ] Command history and replay
- [ ] Integration with approval workflows

## License

Part of NubiferOS - GPL-3.0
