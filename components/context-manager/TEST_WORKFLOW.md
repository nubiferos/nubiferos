# Context Manager Test Workflow

## Installation Test

```bash
cd components/context-manager
sudo ./install.sh
```

Expected output:
- ✓ System dependencies installed
- ✓ Source files copied
- ✓ CLI wrapper created
- ✓ Shell integration installed

## Basic Workflow Test

### 1. Check Status

```bash
nubifer-workspace status
```

Expected:
- Database location shown
- 0 workspaces initially
- No current workspace

### 2. Create AWS Workspace

```bash
nubifer-workspace create \
  --name "AWS Production" \
  --provider aws \
  --account-id 123456789012 \
  --region us-east-1
```

Expected output:
```
✓ Workspace created: AWS Production
  ID: abc123def456
  Provider: ☁️ AWS
  Account: 123456789012
  Region: us-east-1
  Mode: 🔓 Read-Write
ℹ Switch to this workspace: nubifer-workspace switch abc123def456
```

### 3. Create Azure Workspace (Read-Only)

```bash
nubifer-workspace create \
  --name "Azure Dev" \
  --provider azure \
  --account-id my-subscription-id \
  --region eastus \
  --read-only
```

Expected:
- Workspace created with 🔒 Read-Only mode

### 4. List Workspaces

```bash
nubifer-workspace list
```

Expected output:
```
Workspaces:
================================================================================
  ☁️ AWS Production
   ID: abc123def456
   Provider: AWS | Account: 123456789012 | Region: us-east-1 | 🔓

  ⛅ Azure Dev
   ID: def456ghi789
   Provider: Azure | Account: my-subscription-id | Region: eastus | 🔒

Total: 2 workspace(s)
```

### 5. List by Provider

```bash
nubifer-workspace list --provider aws
```

Expected:
- Only AWS workspaces shown

### 6. List in JSON Format

```bash
nubifer-workspace list --format json
```

Expected:
- JSON array of workspaces

### 7. Switch Workspace

```bash
nubifer-workspace switch abc123def456
```

Expected output:
```
============================================================
☁️ Workspace: AWS Production
============================================================
Provider:  AWS
Account:   123456789012
Region:    us-east-1
Mode:      🔓 Read-Write
============================================================

# Run this command to activate workspace:
eval $(nubifer-workspace env abc123def456)
```

### 8. Show Current Workspace

```bash
nubifer-workspace current
```

Expected:
- Shows AWS Production workspace details

### 9. Export Environment Variables

```bash
nubifer-workspace env abc123def456
```

Expected output (shell commands):
```bash
export NUBIFEROS_WORKSPACE_ID='abc123def456'
export NUBIFEROS_WORKSPACE_NAME='AWS Production'
export NUBIFEROS_WORKSPACE_READ_ONLY='false'
export NUBIFEROS_PROVIDER='aws'
export NUBIFEROS_ACCOUNT='123456789012'
export NUBIFEROS_ACCOUNT_ID='123456789012'
export AWS_DEFAULT_REGION='us-east-1'
export AWS_REGION='us-east-1'
export AWS_ACCOUNT_ID='123456789012'
export NUBIFEROS_PROMPT_COLOR='208'
export NUBIFEROS_PROMPT_ICON='☁️'
export NUBIFEROS_PROMPT_NAME='123456789012'
export PS1='[☁️ 123456789012] \u@\h:\w\$ '
```

### 10. Activate in Shell

```bash
eval $(nubifer-workspace env abc123def456)
```

Expected:
- Prompt changes to show workspace context
- Environment variables set

Verify:
```bash
echo $AWS_REGION
# Should output: us-east-1

echo $NUBIFEROS_WORKSPACE_NAME
# Should output: AWS Production
```

### 11. Set Read-Only Mode

```bash
nubifer-workspace set-readonly abc123def456 true
```

Expected:
```
✓ Read-only mode enabled: AWS Production 🔒
```

Verify:
```bash
nubifer-workspace current
# Should show: Mode: 🔒 Read-Only
```

Disable:
```bash
nubifer-workspace set-readonly abc123def456 false
```

### 12. Delete Workspace

First, switch to different workspace:
```bash
nubifer-workspace switch def456ghi789
```

Then delete:
```bash
nubifer-workspace delete abc123def456
```

Expected:
```
Are you sure you want to delete this workspace? [y/N]: y
✓ Deleted workspace: AWS Production
```

Verify:
```bash
nubifer-workspace list
# Should only show Azure Dev workspace
```

## Shell Integration Test

### 1. Source Shell Integration

```bash
source /etc/profile.d/nubiferos-context.sh
```

### 2. Test Aliases

```bash
# Short alias
nw list

# Context alias
nw-context

# Switch alias
nw-switch <workspace-id>
```

### 3. Test Functions

```bash
# Activate workspace
nubifer_activate <workspace-id>

# Show context
nubifer_context
```

Expected:
- Functions work correctly
- Aliases expand properly

### 4. Test Auto-Load

Create a workspace and switch to it:
```bash
nubifer-workspace create --name "Test" --provider aws --account-id 111
nubifer-workspace switch <workspace-id>
```

Open new terminal:
```bash
# New shell should auto-load workspace
echo $NUBIFEROS_WORKSPACE_NAME
# Should output: Test
```

## D-Bus Interface Test

### 1. Check Service

```bash
# Start D-Bus service (in background)
nubifer-context-service &

# Check if service is running
dbus-send --session --print-reply \
  --dest=org.nubiferos.ContextManager \
  /org/nubiferos/ContextManager \
  org.freedesktop.DBus.Introspectable.Introspect
```

Expected:
- Service responds with interface definition

### 2. Create Workspace via D-Bus

```python
import dbus

bus = dbus.SessionBus()
service = bus.get_object(
    'org.nubiferos.ContextManager',
    '/org/nubiferos/ContextManager'
)

workspace_id = service.CreateWorkspace(
    'Test Workspace',
    'aws',
    '999999999999',
    'us-west-2',
    '',
    False,
    dbus_interface='org.nubiferos.ContextManager'
)

print(f"Created workspace: {workspace_id}")
```

### 3. List Workspaces via D-Bus

```python
workspaces = service.ListWorkspaces(
    '',  # All providers
    dbus_interface='org.nubiferos.ContextManager'
)

for ws in workspaces:
    print(f"{ws['name']}: {ws['provider']}")
```

## Error Handling Test

### 1. Invalid Provider

```bash
nubifer-workspace create --name "Test" --provider invalid --account-id 123
```

Expected:
```
✗ Failed to create workspace: Unsupported provider: invalid
```

### 2. Delete Active Workspace

```bash
nubifer-workspace switch <workspace-id>
nubifer-workspace delete <workspace-id>
```

Expected:
```
✗ Cannot delete active workspace
ℹ Switch to another workspace first
```

### 3. Workspace Not Found

```bash
nubifer-workspace switch nonexistent
```

Expected:
```
✗ Workspace not found: nonexistent
```

## Integration Test with Credential Manager

### 1. Create Credential

```bash
nubifer-creds add --provider aws --account-id 123456789012 --account-name prod
```

### 2. Create Workspace with Credential

```bash
nubifer-workspace create \
  --name "AWS Prod" \
  --provider aws \
  --account-id 123456789012 \
  --credential-id <from-nubifer-creds>
```

Expected:
- Workspace created with credential link

### 3. Verify Credential Link

```bash
nubifer-workspace list --format json | jq '.[] | select(.name=="AWS Prod") | .credential_id'
```

Expected:
- Shows credential ID

## Performance Test

### 1. Create Multiple Workspaces

```bash
for i in {1..10}; do
  nubifer-workspace create \
    --name "Test $i" \
    --provider aws \
    --account-id "11111111111$i"
done
```

### 2. List Performance

```bash
time nubifer-workspace list
```

Expected:
- Fast response (< 1 second)

### 3. Switch Performance

```bash
time nubifer-workspace switch <workspace-id>
```

Expected:
- Fast response (< 1 second)

## Cleanup

```bash
# Delete all test workspaces
nubifer-workspace list --format json | jq -r '.[].workspace_id' | while read id; do
  nubifer-workspace delete "$id" --yes
done
```

## Success Criteria

- ✅ All commands execute without errors
- ✅ Workspaces created and listed correctly
- ✅ Environment variables exported properly
- ✅ Shell integration works
- ✅ D-Bus interface responds
- ✅ Read-only mode flag works
- ✅ Error handling is clear
- ✅ Performance is acceptable
