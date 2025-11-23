# Calamares Installer Fixes

## Issues Identified and Fixed

### 1. ✅ Auto-Login and Auto-Start Installer
**Problem:** Had to manually login as "live" user, then manually launch Calamares

**Fix:**
- Updated `build/configure-installer-autostart.sh` to configure GDM3 auto-login for "live" user
- Created desktop autostart entry at `/home/live/.config/autostart/calamares.desktop`
- Added systemd service `calamares-autostart.service` as backup
- Configured to use `pkexec` to request root password when launching

**Files Modified:**
- `build/configure-installer-autostart.sh`
- `installer/calamares/autostart/calamares.desktop` (created)

### 2. ✅ Sudoers File Permissions
**Problem:** Installation failed with "cannot create sudoers file for writing"

**Fix:**
- Added sudoers directory permission fix in `build/install-calamares.sh`
- Ensures `/etc/sudoers.d` has correct permissions (755)
- Ensures sudoers files have correct permissions (440)
- Updated `users.conf` to properly configure sudo group

**Files Modified:**
- `build/install-calamares.sh`
- `installer/calamares/modules/users.conf`

### 3. ✅ Disk Encryption Required by Default
**Problem:** Had to manually check "encrypt disk" option

**Fix:**
- Updated `installer/calamares/modules/partition.conf`
- Set `enableLuksAutomatedPartitioning: true`
- Set `luksGeneration: luks2` (modern LUKS2 format)
- Set `requiredStorageEncryption: true` (user cannot disable)

**Files Modified:**
- `installer/calamares/modules/partition.conf`

### 4. ✅ Package Selection UI
**Problem:** No package selection screen during installation

**Fix:**
- Created `installer/calamares/modules/packagechooser.conf`
- Added three package groups:
  - Cloud Development Tools (AWS CLI, Terraform, kubectl, Docker)
  - Development Tools (VS Code, Git, build tools)
  - Security & Hardening (Firejail, AppArmor, fail2ban) - required
- Updated `installer/calamares/settings.conf` to include packagechooser in sequence

**Files Modified:**
- `installer/calamares/modules/packagechooser.conf` (created)
- `installer/calamares/settings.conf`

### 5. ✅ Root Password Requirement
**Problem:** Root password configuration unclear

**Fix:**
- Updated `installer/calamares/modules/users.conf`
- Set `setRootPassword: true` (require root password)
- Set `doReusePassword: true` (use same password as user by default)
- Increased minimum password length to 12 characters for security

**Files Modified:**
- `installer/calamares/modules/users.conf`

## Configuration Files Updated

### Core Configuration
- `installer/calamares/settings.conf` - Main Calamares configuration
- `installer/calamares/modules/users.conf` - User and password configuration
- `installer/calamares/modules/partition.conf` - Disk partitioning and encryption
- `installer/calamares/modules/packagechooser.conf` - Package selection UI

### Build Scripts
- `build/install-calamares.sh` - Calamares installation
- `build/configure-installer-autostart.sh` - Auto-login and auto-start configuration

### Autostart
- `installer/calamares/autostart/calamares.desktop` - Desktop autostart entry

## Testing Checklist

When testing the new ISO:

- [ ] ISO boots automatically to desktop (no manual login)
- [ ] Calamares installer launches automatically after desktop loads
- [ ] Disk encryption is enabled and required by default
- [ ] Package selection screen appears during installation
- [ ] Can select which package groups to install
- [ ] Root password is requested (or reuses user password)
- [ ] Installation completes successfully without sudoers errors
- [ ] System boots after installation with encryption working

## Next Steps

1. Rebuild the ISO:
   ```bash
   sudo ./build-nubiferos.sh
   ```

2. Test in VirtualBox or QEMU:
   ```bash
   qemu-system-x86_64 -cdrom output/nubiferos-*.iso -m 4096 -enable-kvm
   ```

3. Verify all 5 issues are resolved

## Notes

- The "live" user (password: "live") is only for the live environment
- After installation, the user creates their own account
- Encryption password is set during installation
- Package selection allows customization while keeping ISO size small
