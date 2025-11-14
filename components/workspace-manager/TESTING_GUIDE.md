# Workspace Manager Testing Guide

## Testing on Your Development Machine

You can test the workspace manager on your current system without building the full ISO.

### Prerequisites

```bash
# Install Python 3 (should already be installed)
python3 --version

# Install Firejail (optional, for security testing)
sudo apt-get install firejail
```

### Quick Test (Without Installation)

```bash
cd components/workspace-manager

# Make scripts executable
chmod +x nubifer-workspace test-workspace.sh

# Run test suite
./test-workspace.sh
```

This will:
- Create test workspaces (AWS, Azure, GCP, Oracle)
- Test all CRUD operations
- Verify audit logging
- Check file permissions
- Clean up after tests

### Manual Testing

#### 1. Test Workspace Manager (No Installation Required)

```bash
cd components/workspace-manager

# Create a workspace
./nubifer-workspace create \
  --name "Test AWS" \
  --provider aws \
  --account-id 123456789012 \
  --account-name "test-account" \
  --region us-east-1

# List workspaces
./nubifer-workspace list

# Get workspace ID from list output
WORKSPACE_ID="<id-from-list>"

# Show current workspace
./nubifer-workspace current

# Switch workspace
./nubifer-workspace switch $WORKSPACE_ID

# Export environment (see what would be set)
./nubifer-workspace env $WORKSPACE_ID

# Enable read-only mode
./nubifer-workspace readonly $WORKSPACE_ID --enable

# Disable read-only mode
./nubifer-workspace readonly $WORKSPACE_ID --disable

# Update workspace
./nubifer-workspace update $WORKSPACE_ID --region us-west-2

# Delete workspace
./nubifer-workspace delete $WORKSPACE_ID
```

#### 2. Test Shell Integration (Requires Installation)

```bash
cd components/workspace-manager

# Install to your system
sudo ./install.sh

# Restart shell or source integration
source /etc/nubifer/shell-integration.sh

# Create workspace
nubifer-workspace create --name "Test" --provider aws --account-id 123

# Activate workspace
eval $(nubifer-workspace env <workspace-id>)

# Check prompt (should show workspace context)
# [☁️ test-account] user@host:~$

# Check environment variables
env | grep NUBIFER
```

#### 3. Test Firejail Integration (Requires Installation)

```bash
cd components/workspace-manager

# Install Firejail integration
sudo ./install-firejail.sh

# Create and activate workspace
nubifer-workspace create --name "Test" --provider aws --account-id 123
eval $(nubifer-workspace env <workspace-id>)

# Run AWS CLI (if installed)
aws --version

# Check if running in Firejail
ps aux | grep firejail

# List active sandboxes
firejail --list

# Check generated profile
cat ~/.config/firejail/nubifer-aws-<workspace-id>.profile
```

### Testing Without Cloud CLIs

If you don't have AWS CLI, Azure CLI, etc. installed, you can still test:

```bash
# Test with any command
echo "test" | firejail --profile=/etc/firejail/nubifer/nubifer-base.profile cat

# Test workspace isolation
mkdir -p ~/.aws/workspace-test1
echo "creds1" > ~/.aws/workspace-test1/credentials

mkdir -p ~/.aws/workspace-test2
echo "creds2" > ~/.aws/workspace-test2/credentials

# Try to read workspace-test2 from workspace-test1 sandbox
# (should fail)
```

## Testing in the ISO Build

### During Build

The workspace manager is automatically installed during ISO build:

```bash
# Build ISO
sudo ./build/build-iso.sh

# Check build log for workspace manager installation
# Should see:
# INFO: Installing Workspace Manager...
# INFO: Installing Firejail integration...
# INFO: ✓ Workspace Manager installed
```

### After Installation

When you install NubiferOS from the ISO:

1. **Post-Install Script Runs Automatically**
   - Asks if you want to enable Firejail isolation
   - Sets up CLI wrappers if you choose yes

2. **Manual Setup (if you declined)**
   ```bash
   # Enable Firejail wrappers later
   sudo /usr/share/nubifer/installer/enable-firejail-wrappers.sh
   
   # Disable if needed
   sudo /usr/share/nubifer/installer/disable-firejail-wrappers.sh
   ```

3. **Test Workspace Manager**
   ```bash
   # Create workspace
   nubifer-workspace create --name "AWS Prod" --provider aws --account-id 123
   
   # Activate
   eval $(nubifer-workspace env <workspace-id>)
   
   # Check prompt
   # [☁️ prod-account] user@host:~$
   ```

## Verification Checklist

### Basic Functionality
- [ ] Can create workspaces for all providers (AWS, Azure, GCP, Oracle)
- [ ] Can list workspaces
- [ ] Can switch between workspaces
- [ ] Can show current workspace
- [ ] Can enable/disable read-only mode
- [ ] Can update workspace properties
- [ ] Can delete workspaces

### Shell Integration
- [ ] Terminal prompt shows workspace context
- [ ] Prompt shows correct provider icon and color
- [ ] Prompt shows 🔒 when read-only mode is enabled
- [ ] Environment variables are set correctly
- [ ] Aliases work (nw, nw-switch, nw-context)

### Firejail Integration
- [ ] Firejail is installed
- [ ] CLI wrappers are created
- [ ] Commands run in Firejail sandbox
- [ ] Workspace-specific profiles are generated
- [ ] Credential isolation works (can't access other workspaces)
- [ ] Read-only mode blocks write operations

### Security
- [ ] Workspace config files have 0600 permissions
- [ ] Config directory has 0700 permissions
- [ ] Audit log is created and updated
- [ ] Cannot access other workspace credentials
- [ ] Read-only mode prevents modifications

### Performance
- [ ] Workspace switching is fast (<1 second)
- [ ] CLI commands have minimal overhead (<10%)
- [ ] No memory leaks (check with `ps aux`)

## Common Issues

### Issue: Command not found

**Problem**: `nubifer-workspace: command not found`

**Solution**:
```bash
# Check if installed
which nubifer-workspace

# If not found, install
cd components/workspace-manager
sudo ./install.sh

# Or add to PATH
export PATH="$PATH:$(pwd)"
```

### Issue: Firejail not working

**Problem**: Commands not running in sandbox

**Solution**:
```bash
# Check if Firejail is installed
firejail --version

# Install if missing
sudo apt-get install firejail

# Check if wrappers are enabled
ls -la /usr/local/bin/aws

# Enable wrappers
sudo /usr/share/nubifer/installer/enable-firejail-wrappers.sh
```

### Issue: Permission denied

**Problem**: Cannot access workspace files

**Solution**:
```bash
# Check file permissions
ls -la ~/.config/nubifer/workspaces/

# Fix permissions
chmod 700 ~/.config/nubifer
chmod 600 ~/.config/nubifer/workspaces/*.json
```

### Issue: Prompt not updating

**Problem**: Terminal prompt doesn't show workspace

**Solution**:
```bash
# Source shell integration
source /etc/nubifer/shell-integration.sh

# Or restart shell
exec bash

# Check if integration is loaded
type nubifer_update_prompt
```

## Automated Testing

Run the full test suite:

```bash
cd components/workspace-manager
./test-workspace.sh
```

Expected output:
```
Testing NubiferOS Workspace Manager...
========================================

Test 1: Creating AWS workspace...
✓ Workspace created: Test AWS Prod

Test 2: Creating Azure workspace...
✓ Workspace created: Test Azure Dev

Test 3: Creating GCP workspace (read-only)...
✓ Workspace created: Test GCP Staging

Test 4: Listing all workspaces...
[Lists workspaces]

Test 5: Listing AWS workspaces...
[Lists AWS workspaces only]

...

========================================
✓ All tests completed successfully!
========================================
```

## Performance Testing

Test workspace switching performance:

```bash
# Create multiple workspaces
for i in {1..10}; do
  nubifer-workspace create \
    --name "Test-$i" \
    --provider aws \
    --account-id "11111111111$i"
done

# Time workspace switching
time nubifer-workspace switch <workspace-id>

# Should be < 1 second
```

Test CLI overhead with Firejail:

```bash
# Without Firejail
time aws --version

# With Firejail
time firejail --profile=~/.config/firejail/nubifer-aws-<id>.profile aws --version

# Overhead should be < 100ms
```

## Cleanup

Remove test data:

```bash
# Remove test workspaces
rm -rf ~/.config/nubifer/

# Remove Firejail profiles
rm -rf ~/.config/firejail/nubifer-*

# Uninstall (if needed)
sudo rm /usr/local/bin/nubifer-workspace
sudo rm /etc/nubifer/shell-integration.sh
sudo rm /usr/local/bin/{aws,az,gcloud,oci}  # If wrappers installed
```

## Next Steps

After testing:

1. **Report Issues**: Document any bugs or unexpected behavior
2. **Performance Tuning**: Optimize slow operations
3. **Documentation**: Update docs based on testing experience
4. **Integration Testing**: Test with real cloud CLIs and credentials
5. **Security Audit**: Review Firejail profiles and isolation

## Support

For issues:
1. Check this testing guide
2. Review documentation in `README.md` and `FIREJAIL_INTEGRATION.md`
3. Check audit log: `~/.config/nubifer/workspace-audit.log`
4. Run with debug: `bash -x nubifer-workspace <command>`
