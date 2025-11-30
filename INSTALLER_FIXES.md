# Installer Fixes Summary

## Issues Fixed

### 1. Package Installation Failures ✅
**Problem:** terraform, kubectl, docker-ce not in Debian repos

**Solution:** Updated package list to use only Debian-available packages:
- `docker.io` instead of `docker-ce`
- Removed terraform, kubectl (can be installed post-install via scripts)
- Added Python cloud SDKs (boto3, azure, google-cloud)
- Added `code-oss` (open source VS Code)

### 2. IDE Support Added ✅
**New package group:** "IDEs and Editors"
- vim, emacs, geany, code-oss
- Optional (not selected by default)
- Users can choose during installation

### 3. Enhanced Security Packages ✅
Added to required security group:
- `rkhunter` - Rootkit detection
- `lynis` - Security auditing

### 4. GRUB Bootloader Issue ⚠️
**Problem:** `grub-install` failing on virtio disk

**Temporary fix:** Added timeout and better config
**Permanent fix needed:** May need to install GRUB packages in chroot

## Package Groups

### Cloud Development Tools
- docker.io, docker-compose
- Python cloud SDKs (AWS, Azure, GCP)
- awscli
- Selected by default

### Development Tools  
- git, build-essential
- Python dev tools
- nodejs, npm
- curl, wget
- Selected by default

### IDEs and Editors (NEW)
- vim, emacs
- geany (lightweight IDE)
- code-oss (VS Code open source)
- NOT selected by default (optional)

### Security & Hardening
- firejail, apparmor, fail2ban
- ufw (firewall)
- aide, rkhunter, lynis
- **REQUIRED** (immutable, cannot deselect)

## Post-Install Tools

For tools not in Debian repos, create post-install scripts:

```bash
# /usr/local/bin/install-cloud-tools
#!/bin/bash
# Install terraform
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get install terraform

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install VS Code (full version)
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
sudo apt-get update && sudo apt-get install code
```

## Testing

```bash
# Rebuild with fixes
sudo ./build-nubiferos.sh

# Test installation
./testing/qemu-with-spice.sh

# Verify packages install correctly
# Check GRUB installs without errors
```

## Next Steps

1. Test new package list
2. Fix GRUB bootloader if still failing
3. Create post-install script for non-Debian packages
4. Add to first-boot wizard
