# Installation Troubleshooting Guide

## Quick Fix

If installation failed, the most common issue is missing directories. The updated install scripts now create all required directories automatically.

### Re-run Installation

```bash
cd components/workspace-manager

# Uninstall first (if partially installed)
sudo rm -f /usr/local/bin/nubifer-workspace
sudo rm -f /etc/nubifer/shell-integration.sh

# Re-install
sudo ./install.sh

# Verify
./verify-install.sh
```

## Common Issues

### Issue 1: "No such file or directory: /etc/nubifer/shell-integration.sh"

**Cause**: The `/etc/nubifer` directory doesn't exist

**Fix**: The updated `install.sh` now creates this directory automatically. Re-run:

```bash
sudo ./install.sh
```

**Manual Fix** (if needed):
```bash
sudo mkdir -p /etc/nubifer
sudo chmod 755 /etc/nubifer
sudo cp shell-integration.sh /etc/nubifer/
sudo chmod 644 /etc/nubifer/shell-integration.sh
```

### Issue 2: "Permission denied"

**Cause**: Not running as root

**Fix**:
```bash
# Use sudo
sudo ./install.sh
```

### Issue 3: "Command not found: nubifer-workspace"

**Cause**: Not in PATH or not installed

**Fix**:
```bash
# Check if installed
ls -la /usr/local/bin/nubifer-workspace

# If not found, install
sudo ./install.sh

# If installed but not in PATH
export PATH="/usr/local/bin:$PATH"

# Or use full path
/usr/local/bin/nubifer-workspace --help
```

### Issue 4: Firejail installation fails

**Cause**: Package not available or network issue

**Fix**:
```bash
# Update package list
sudo apt-get update

# Install Firejail manually
sudo apt-get install -y firejail

# Then run Firejail integration
sudo ./install-firejail.sh
```

### Issue 5: "cp: cannot stat 'cli-wrappers/*'"

**Cause**: Running install script from wrong directory

**Fix**:
```bash
# Make sure you're in the workspace-manager directory
cd components/workspace-manager

# Check files exist
ls -la cli-wrappers/

# Then install
sudo ./install.sh
sudo ./install-firejail.sh
```

### Issue 6: Shell integration not working

**Cause**: Shell integration not sourced

**Fix**:
```bash
# Source manually
source /etc/nubifer/shell-integration.sh

# Or restart shell
exec bash

# Or add to your ~/.bashrc
echo 'source /etc/nubifer/shell-integration.sh' >> ~/.bashrc
```

## Verification Steps

### Step 1: Check Installation

```bash
./verify-install.sh
```

Expected output:
```
✓ nubifer-workspace command found
✓ /etc/nubifer exists
✓ /usr/local/lib/nubifer exists
✓ /usr/local/bin/nubifer-workspace exists
✓ /etc/nubifer/shell-integration.sh exists
```

### Step 2: Test Basic Functionality

```bash
# Test command
nubifer-workspace --help

# Create test workspace
nubifer-workspace create \
  --name "Test" \
  --provider aws \
  --account-id 123456789012

# List workspaces
nubifer-workspace list

# Should show the test workspace
```

### Step 3: Test Shell Integration

```bash
# Source integration
source /etc/nubifer/shell-integration.sh

# Check if functions are loaded
type nubifer_update_prompt

# Should show function definition
```

### Step 4: Test Firejail (if installed)

```bash
# Check Firejail
firejail --version

# Check profiles
ls -la /etc/firejail/nubifer/

# Check wrappers
ls -la /usr/local/lib/nubifer/cli-wrappers/
```

## Complete Reinstallation

If all else fails, completely remove and reinstall:

```bash
cd components/workspace-manager

# 1. Remove everything
sudo rm -f /usr/local/bin/nubifer-workspace
sudo rm -rf /etc/nubifer
sudo rm -rf /usr/local/lib/nubifer
sudo rm -rf /etc/firejail/nubifer
sudo rm -f /usr/local/bin/{aws,az,gcloud,oci}  # If wrappers installed

# 2. Remove user data (optional - will delete workspaces!)
rm -rf ~/.config/nubifer

# 3. Reinstall
sudo ./install.sh

# 4. Install Firejail integration (optional)
sudo ./install-firejail.sh

# 5. Verify
./verify-install.sh

# 6. Restart shell
exec bash
```

## Directory Structure

After successful installation, you should have:

```
/usr/local/bin/
└── nubifer-workspace                    # Main command

/etc/nubifer/
└── shell-integration.sh                 # Shell integration

/usr/local/lib/nubifer/
├── firejail-wrapper.sh                  # Firejail wrapper (if installed)
└── cli-wrappers/                        # CLI wrappers (if installed)
    ├── aws
    ├── az
    ├── gcloud
    └── oci

/etc/firejail/nubifer/                   # Firejail profiles (if installed)
├── nubifer-base.profile
├── nubifer-aws.profile
├── nubifer-azure.profile
├── nubifer-gcp.profile
└── nubifer-oracle.profile

~/.config/nubifer/                       # User data (created on first use)
├── workspaces/
│   └── <workspace-id>.json
├── current-workspace
└── workspace-audit.log
```

## File Permissions

Correct permissions:

```bash
# System files (should be owned by root)
-rwxr-xr-x  /usr/local/bin/nubifer-workspace
-rw-r--r--  /etc/nubifer/shell-integration.sh
drwxr-xr-x  /etc/nubifer/
drwxr-xr-x  /usr/local/lib/nubifer/
-rwxr-xr-x  /usr/local/lib/nubifer/firejail-wrapper.sh
-rwxr-xr-x  /usr/local/lib/nubifer/cli-wrappers/*

# User files (should be owned by user)
drwx------  ~/.config/nubifer/
-rw-------  ~/.config/nubifer/workspaces/*.json
-rw-------  ~/.config/nubifer/current-workspace
-rw-------  ~/.config/nubifer/workspace-audit.log
```

## Testing After Installation

### Basic Test

```bash
# Create workspace
nubifer-workspace create --name "Test" --provider aws --account-id 123

# List
nubifer-workspace list

# Should show:
# Workspaces:
# ================================================================================
#   ☁️ Test
#    ID: <workspace-id>
#    Provider: AWS | Account: 123 | 🔓
```

### Shell Integration Test

```bash
# Activate workspace
eval $(nubifer-workspace env <workspace-id>)

# Check prompt (should show workspace)
# [☁️ 123] user@host:~$

# Check environment
env | grep NUBIFER
# Should show:
# NUBIFER_WORKSPACE_ID=<id>
# NUBIFER_WORKSPACE_PROVIDER=aws
# etc.
```

### Firejail Test (if installed)

```bash
# Activate workspace
eval $(nubifer-workspace env <workspace-id>)

# Run a command (any command)
echo "test" | cat

# Check if Firejail is active
ps aux | grep firejail

# List sandboxes
firejail --list
```

## Getting Help

If you're still having issues:

1. **Check the logs**:
   ```bash
   # Installation output
   sudo ./install.sh 2>&1 | tee install.log
   
   # Workspace audit log
   cat ~/.config/nubifer/workspace-audit.log
   ```

2. **Run verification**:
   ```bash
   ./verify-install.sh
   ```

3. **Check system**:
   ```bash
   # OS version
   lsb_release -a
   
   # Python version
   python3 --version
   
   # Firejail version (if installed)
   firejail --version
   ```

4. **Review documentation**:
   - `README.md` - User guide
   - `FIREJAIL_INTEGRATION.md` - Security details
   - `TESTING_GUIDE.md` - Testing instructions

## Known Issues

### Issue: Firejail not available on some systems

**Workaround**: Workspace manager works without Firejail, just without sandbox isolation.

```bash
# Install workspace manager only
sudo ./install.sh

# Skip Firejail integration
# Workspaces will still work, just without sandboxing
```

### Issue: Shell integration not loading automatically

**Workaround**: Add to your `~/.bashrc`:

```bash
echo 'source /etc/nubifer/shell-integration.sh' >> ~/.bashrc
source ~/.bashrc
```

### Issue: CLI wrappers conflict with existing tools

**Workaround**: Disable Firejail wrappers:

```bash
sudo /usr/share/nubifer/installer/disable-firejail-wrappers.sh
```

## Success Indicators

You know installation succeeded when:

1. ✅ `nubifer-workspace --help` works
2. ✅ `./verify-install.sh` shows all green checkmarks
3. ✅ You can create and list workspaces
4. ✅ Terminal prompt shows workspace context after activation
5. ✅ `env | grep NUBIFER` shows workspace variables

## Next Steps

After successful installation:

1. **Create your first workspace**:
   ```bash
   nubifer-workspace create \
     --name "AWS Production" \
     --provider aws \
     --account-id <your-account-id> \
     --region us-east-1
   ```

2. **Read the documentation**:
   - `README.md` for usage guide
   - `FIREJAIL_INTEGRATION.md` for security details

3. **Set up credentials**:
   ```bash
   # Use nubifer-creds (if installed)
   nubifer-creds add --type aws --name prod-creds
   ```

4. **Start using workspaces**:
   ```bash
   eval $(nubifer-workspace env <workspace-id>)
   aws s3 ls  # Or any cloud CLI command
   ```
