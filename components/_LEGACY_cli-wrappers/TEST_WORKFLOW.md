# CLI Wrappers Test Workflow

## Prerequisites

1. Credential Manager installed and configured
2. Context Manager installed and configured
3. At least one workspace created with credentials
4. Cloud CLI tools installed (/usr/bin/aws, /usr/bin/az, etc.)

## Installation Test

```bash
cd components/cli-wrappers
sudo ./install-wrappers.sh
```

Expected output:
- ✓ Wrapper files copied
- ✓ Wrapper scripts created in /usr/local/bin
- List of installed wrappers

Verify installation:
```bash
which aws
# Should show: /usr/local/bin/aws

which az
# Should show: /usr/local/bin/az

which gcloud
# Should show: /usr/local/bin/gcloud
```

## Test 1: No Active Workspace

```bash
# Ensure no workspace is active
unset NUBIFEROS_WORKSPACE_ID

# Try to use AWS CLI
aws ec2 describe-instances
```

Expected output:
```
⚠ No active workspace. Activate one with:
  nubifer-workspace list
  eval $(nubifer-workspace env <workspace-id>)
```

## Test 2: Activate Workspace

```bash
# List workspaces
nubifer-workspace list

# Activate a workspace
eval $(nubifer-workspace env <workspace-id>)

# Verify environment
echo $NUBIFEROS_WORKSPACE_ID
echo $NUBIFEROS_WORKSPACE_NAME
```

Expected:
- Workspace ID and name displayed
- Environment variables set

## Test 3: Read Operations (Should Work)

```bash
# AWS read operations
aws ec2 describe-instances
aws s3 ls
aws iam list-users

# Azure read operations
az vm list
az group list

# GCP read operations
gcloud compute instances list
gcloud projects list

# Terraform read operations
terraform plan
terraform show
terraform validate

# Kubectl read operations
kubectl get pods
kubectl describe nodes
kubectl get services
```

Expected:
- All commands execute successfully
- Credentials automatically injected
- No credential exposure in environment

## Test 4: Enable Read-Only Mode

```bash
# Get current workspace ID
WORKSPACE_ID=$(echo $NUBIFEROS_WORKSPACE_ID)

# Enable read-only mode
nubifer-workspace set-readonly $WORKSPACE_ID true

# Verify
nubifer-workspace current
```

Expected output:
```
✓ Read-only mode enabled: <workspace-name> 🔒

Current Workspace:
...
Mode:      🔒 Read-Only
```

## Test 5: Write Operations Blocked in Read-Only

### AWS Write Operations (Should Block)

```bash
# Try to create tags
aws ec2 create-tags --resources i-123456 --tags Key=Test,Value=Value

# Try to terminate instance
aws ec2 terminate-instances --instance-ids i-123456

# Try to create S3 bucket
aws s3 mb s3://test-bucket

# Try to delete S3 object
aws s3 rm s3://bucket/key
```

Expected output for each:
```
❌ Operation blocked: Workspace '<name>' is in READ-ONLY mode.
   Use 'nubifer-workspace set-readonly <id> false' to enable writes.
```

### Azure Write Operations (Should Block)

```bash
# Try to create resource group
az group create --name test-rg --location eastus

# Try to delete VM
az vm delete --name myvm --resource-group myrg

# Try to start VM
az vm start --name myvm --resource-group myrg
```

Expected: All blocked with read-only error message

### GCP Write Operations (Should Block)

```bash
# Try to create instance
gcloud compute instances create test-instance

# Try to delete instance
gcloud compute instances delete myinstance

# Try to update firewall
gcloud compute firewall-rules update myrule
```

Expected: All blocked with read-only error message

### Terraform Write Operations (Should Block)

```bash
# Try to apply changes
terraform apply

# Try to destroy resources
terraform destroy
```

Expected: All blocked with read-only error message

### Kubectl Write Operations (Should Block)

```bash
# Try to create pod
kubectl create deployment nginx --image=nginx

# Try to delete pod
kubectl delete pod mypod

# Try to scale deployment
kubectl scale deployment nginx --replicas=3
```

Expected: All blocked with read-only error message

## Test 6: Read Operations Still Work in Read-Only

```bash
# These should still work
aws ec2 describe-instances
az vm list
gcloud compute instances list
terraform plan
kubectl get pods
```

Expected:
- All read operations work normally
- No blocking

## Test 7: Disable Read-Only Mode

```bash
# Disable read-only mode
nubifer-workspace set-readonly $WORKSPACE_ID false

# Verify
nubifer-workspace current
```

Expected output:
```
✓ Read-only mode disabled: <workspace-name> 🔓

Current Workspace:
...
Mode:      🔓 Read-Write
```

## Test 8: Write Operations Work in Read-Write

```bash
# Re-activate workspace to get updated read-only status
eval $(nubifer-workspace env $WORKSPACE_ID)

# Try a safe write operation (if you have test resources)
aws ec2 create-tags --resources i-123456 --tags Key=Test,Value=Value

# Or test with dry-run
aws ec2 run-instances --dry-run --image-id ami-12345 --instance-type t2.micro
```

Expected:
- Commands execute (or fail with AWS errors, not wrapper errors)
- No read-only blocking

## Test 9: Bypass Wrappers

```bash
# Use real binaries directly
/usr/bin/aws ec2 describe-instances

# This will fail with authentication error (no credentials injected)
```

Expected:
- Command executes but fails with AWS authentication error
- Proves wrappers are injecting credentials

## Test 10: Multiple Workspaces

```bash
# Create second workspace
nubifer-workspace create \
  --name "AWS Dev" \
  --provider aws \
  --account-id 999999999999

# Switch to new workspace
nubifer-workspace switch <new-workspace-id>
eval $(nubifer-workspace env <new-workspace-id>)

# Verify different credentials are used
aws sts get-caller-identity
```

Expected:
- Different account ID shown
- Proves credential isolation works

## Test 11: Terraform with Different Providers

```bash
# Create Terraform file
cat > test.tf << 'EOF'
provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "test" {
  bucket = "test-bucket-nubiferos"
}
EOF

# Plan (should work)
terraform init
terraform plan

# Apply in read-only (should block)
nubifer-workspace set-readonly $WORKSPACE_ID true
eval $(nubifer-workspace env $WORKSPACE_ID)
terraform apply
```

Expected:
- `terraform plan` works
- `terraform apply` blocked in read-only mode

## Test 12: Error Handling

### Test Missing Real Binary

```bash
# Temporarily rename real binary
sudo mv /usr/bin/aws /usr/bin/aws.bak

# Try wrapper
aws ec2 describe-instances
```

Expected:
```
✗ Error: Real binary not found: /usr/bin/aws
```

Restore:
```bash
sudo mv /usr/bin/aws.bak /usr/bin/aws
```

### Test D-Bus Service Down

```bash
# Stop D-Bus services (if running)
# Try wrapper
aws ec2 describe-instances
```

Expected:
- Error about D-Bus connection failure

## Test 13: Performance

```bash
# Time wrapper execution
time aws ec2 describe-instances

# Time direct execution (for comparison)
time /usr/bin/aws ec2 describe-instances
```

Expected:
- Wrapper adds minimal overhead (< 100ms)

## Test 14: GCP Temporary Key File

```bash
# Activate GCP workspace
eval $(nubifer-workspace env <gcp-workspace-id>)

# Run gcloud command
gcloud compute instances list

# Check for temp files
ls -la /tmp/gcp-key-*
```

Expected:
- Temp key file created during execution
- Temp key file cleaned up after execution
- No leftover temp files

## Cleanup

```bash
# Remove test Terraform files
rm -f test.tf .terraform* terraform.tfstate*

# Reset workspace to read-write
nubifer-workspace set-readonly $WORKSPACE_ID false
```

## Success Criteria

- ✅ Wrappers installed correctly
- ✅ No active workspace error shown appropriately
- ✅ Read operations work with credentials injected
- ✅ Write operations blocked in read-only mode
- ✅ Write operations work in read-write mode
- ✅ Error messages are clear and helpful
- ✅ Credential isolation between workspaces
- ✅ Minimal performance overhead
- ✅ Temp files cleaned up properly
- ✅ Real binaries can be bypassed if needed

## Common Issues

### PATH Not Updated

If wrappers aren't being used:
```bash
echo $PATH
# Ensure /usr/local/bin comes before /usr/bin

# If not, add to ~/.bashrc:
export PATH="/usr/local/bin:$PATH"
```

### D-Bus Services Not Running

Start services manually:
```bash
nubifer-creds-service &
nubifer-context-service &
```

### Credentials Not Found

Ensure credentials are added:
```bash
nubifer-creds list
# If empty, add credentials
nubifer-creds add --provider aws --account-id 123456789012 --account-name prod
```
