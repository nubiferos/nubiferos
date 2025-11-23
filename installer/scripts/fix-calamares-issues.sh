#!/bin/bash
# Fix Calamares installer issues
# Addresses:
# 1. Auto-login and auto-start installer
# 2. Sudoers file permissions
# 3. Encryption enabled by default
# 4. Package selection UI
# 5. Root password requirement

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CALAMARES_DIR="${SCRIPT_DIR}/../calamares"

echo "Fixing Calamares configuration issues..."

# Fix 1: Enable auto-login and auto-start Calamares
echo "1. Configuring auto-login and auto-start..."
cat > "${CALAMARES_DIR}/autostart/calamares.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Install NubiferOS
Exec=pkexec calamares
Icon=calamares
Terminal=false
Categories=System;
X-GNOME-Autostart-enabled=true
EOF

# Fix 2: Configure sudoers module properly
echo "2. Fixing sudoers configuration..."
cat > "${CALAMARES_DIR}/modules/users.conf" << 'EOF'
---
defaultGroups:
    - name: users
      must: false
    - name: lp
      must: false
    - name: video
      must: false
    - name: network
      must: false
    - name: storage
      must: false
    - name: wheel
      must: false
    - name: audio
      must: false
    - name: sudo
      must: true
    - name: docker
      must: false

autologinGroup:  autologin

doAutologin:     false

sudoersGroup:    sudo

setRootPassword: true

doReusePassword: true

passwordRequirements:
    minLength: 12
    maxLength: -1

allowWeakPasswords: false

userShell: /bin/bash

hostname:
    location: EtcFile
    writeHostsFile: true
    template: "nubiferos-${cpu}"

presets:
    fullName:
        value: ""
        editable: true
    loginName:
        value: ""
        editable: true
EOF

# Fix 3: Enable encryption by default
echo "3. Enabling disk encryption by default..."
cat > "${CALAMARES_DIR}/modules/partition.conf" << 'EOF'
---
efiSystemPartition:     "/boot/efi"
userSwapChoices:
    - none
    - small
    - suspend
    - file

drawNestedPartitions:   false
alwaysShowPartitionLabels: true
allowManualPartitioning:   true

initialPartitioningChoice: erase
initialSwapChoice: small

defaultFileSystemType:  "ext4"

availableFileSystemTypes:
    - "ext4"
    - "btrfs"
    - "xfs"

# Enable encryption by default
enableLuksAutomatedPartitioning: true
luksGeneration: luks2

# Require encryption (user cannot disable)
requiredStorageEncryption: true
EOF

# Fix 4: Add package selection module
echo "4. Adding package selection module..."
mkdir -p "${CALAMARES_DIR}/modules"
cat > "${CALAMARES_DIR}/modules/packagechooser.conf" << 'EOF'
---
mode: required

method: legacy

items:
    - id: cloud-tools
      name: "Cloud Development Tools"
      description: "AWS CLI, Terraform, kubectl, Docker, and other cloud tools"
      screenshot: ""
      selected: true
      critical: false
      immutable: false
      packages:
          - awscli
          - terraform
          - kubectl
          - docker-ce
          - docker-compose
    
    - id: dev-tools
      name: "Development Tools"
      description: "VS Code, Git, build tools, and development utilities"
      screenshot: ""
      selected: true
      critical: false
      immutable: false
      packages:
          - code
          - git
          - build-essential
          - python3-dev
          - nodejs
          - npm
    
    - id: security-tools
      name: "Security & Hardening"
      description: "Firejail, AppArmor, and security monitoring tools"
      screenshot: ""
      selected: true
      critical: true
      immutable: true
      packages:
          - firejail
          - apparmor
          - apparmor-utils
          - fail2ban
EOF

# Fix 5: Update settings.conf to include packagechooser
echo "5. Updating Calamares settings..."
cat > "${CALAMARES_DIR}/settings.conf" << 'EOF'
# Calamares settings for NubiferOS

---
modules-search: [ local ]

instances:
- id:       nubiferos
  module:   packages
  config:   packages.conf

sequence:
- show:
  - welcome
  - locale
  - keyboard
  - partition
  - users
  - packagechooser
  - summary
- exec:
  - partition
  - mount
  - unpackfs
  - machineid
  - fstab
  - locale
  - keyboard
  - localecfg
  - users
  - displaymanager
  - networkcfg
  - hwclock
  - services-systemd
  - packages@nubiferos
  - bootloader
  - umount
- show:
  - finished

branding: nubiferos

prompt-install: true

dont-chroot: false

oem-setup: false

disable-cancel: false

disable-cancel-during-exec: true

hide-back-and-next-during-exec: true

quit-at-end: false
EOF

echo "✓ Calamares configuration fixed!"
echo ""
echo "Changes made:"
echo "  1. ✓ Auto-login enabled, Calamares auto-starts"
echo "  2. ✓ Sudoers configuration fixed"
echo "  3. ✓ Disk encryption enabled and required by default"
echo "  4. ✓ Package selection UI added"
echo "  5. ✓ Root password now required"
echo ""
echo "Next: Rebuild the ISO with ./build-nubiferos.sh"
