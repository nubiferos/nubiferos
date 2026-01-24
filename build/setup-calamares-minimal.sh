#!/bin/bash
# Quick setup script to create minimal Calamares configuration
# This gets the installer working quickly for testing

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CALAMARES_DIR="${PROJECT_ROOT}/installer/calamares"

echo "=========================================="
echo "Setting up minimal Calamares configuration"
echo "=========================================="
echo ""

# Create directory structure
echo "Creating directory structure..."
mkdir -p "${CALAMARES_DIR}/modules"
mkdir -p "${CALAMARES_DIR}/branding/nubiferos"

# Create branding descriptor
echo "Creating branding..."
cat > "${CALAMARES_DIR}/branding/nubiferos/branding.desc" << 'EOF'
---
componentName:  nubiferos

strings:
    productName:         "NubiferOS"
    shortProductName:    "NubiferOS"
    version:             "1.0"
    shortVersion:        "1.0"
    versionedName:       "NubiferOS 1.0"
    shortVersionedName:  "NubiferOS 1.0"
    bootloaderEntryName: "NubiferOS"
    productUrl:          "https://nubiferos.io"
    supportUrl:          "https://github.com/nubiferos/nubiferos"
    knownIssuesUrl:      "https://github.com/nubiferos/nubiferos/issues"
    releaseNotesUrl:     "https://github.com/nubiferos/nubiferos/releases"

images:
    productLogo:         "logo.png"
    productIcon:         "logo.png"
    productWelcome:      "welcome.png"

slideshow:              "show.qml"

style:
   sidebarBackground:    "#2c3e50"
   sidebarText:          "#ffffff"
   sidebarTextSelect:    "#3498db"
   sidebarTextHighlight: "#3498db"
EOF

# Create simple logo (text-based placeholder)
echo "Creating placeholder logo..."
cat > "${CALAMARES_DIR}/branding/nubiferos/logo.png.txt" << 'EOF'
# Placeholder - replace with actual logo.png
# For now, Calamares will use default
EOF

# Create welcome image placeholder
cp "${CALAMARES_DIR}/branding/nubiferos/logo.png.txt" \
   "${CALAMARES_DIR}/branding/nubiferos/welcome.png.txt"

# Create slideshow
# Slideshow is now managed in installer/calamares/branding/nubiferos/show.qml
# No need to generate it here - the proper 15-slide version will be copied during build
echo "Slideshow will be copied from installer/calamares/branding/nubiferos/show.qml"

# Create module configs
echo "Creating module configurations..."

# Welcome module
cat > "${CALAMARES_DIR}/modules/welcome.conf" << 'EOF'
---
showSupportUrl:         true
showKnownIssuesUrl:     true
showReleaseNotesUrl:    true

requirements:
    requiredStorage:    10.0
    requiredRam:        2.0
    internetCheckUrl:   http://google.com
    check:
        - storage
        - ram
        - power
        - internet
        - root
    required:
        - storage
        - ram
        - root
EOF

# Partition module - LUKS2 with unencrypted /boot for maximum security
cat > "${CALAMARES_DIR}/modules/partition.conf" << 'EOF'
---
# NubiferOS Partition Configuration
# LUKS2 + Argon2id with unencrypted /boot for maximum security

efi:
    mountPoint: "/boot/efi"
    recommendedSize: 512MiB
    minimumSize: 256MiB
    label: "EFI"

userSwapChoices:
    - none
    - small
    - suspend
    - file

drawNestedPartitions: false
alwaysShowPartitionLabels: true
allowManualPartitioning: true

initialPartitioningChoice: erase
initialSwapChoice: small

defaultFileSystemType: "ext4"
defaultPartitionTableType: "gpt"

availableFileSystemTypes:
    - "ext4"
    - "btrfs"
    - "xfs"

# LUKS2 Encryption Settings
# Use LUKS2 with Argon2id (default) for maximum security against GPU attacks
# /boot remains unencrypted so GRUB doesn't need to decrypt anything
# The initramfs handles LUKS2 decryption after kernel loads
enableLuksAutomatedPartitioning: true
preCheckEncryption: true
luksGeneration: luks2

# Don't show warning about unencrypted /boot - this is intentional
showNotEncryptedBootMessage: false

# Custom partition layout for LUKS2 compatibility
partitionLayout:
    - name: "EFI"
      type: "EF00"
      filesystem: "fat32"
      mountPoint: "/boot/efi"
      size: 512MiB
      minSize: 256MiB
      maxSize: 1GiB
    - name: "boot"
      filesystem: "ext4"
      mountPoint: "/boot"
      size: 1GiB
      minSize: 512MiB
      maxSize: 2GiB
      features:
        - noluks
    - name: "root"
      filesystem: "ext4"
      mountPoint: "/"
      size: 100%
      minSize: 10GiB
      features:
        - luks
EOF

# Users module  
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

setRootPassword: false

doReusePassword: false

passwordRequirements:
    minLength: 8
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

# Packages module
cat > "${CALAMARES_DIR}/modules/packages.conf" << 'EOF'
---
backend: apt

operations:
  - install:
    # Base utilities
    - vim
    - curl
    - wget
    - git
    - htop
    - tmux
    - net-tools
    - jq
    - unzip
    - ca-certificates
    # Base development dependencies (always installed for cloud tools)
    - python3
    - python3-pip
    - python3-venv
    - python3-dev
    - nodejs
    - npm
    - build-essential
    - gcc
    - g++
    - make
  - remove:
    - calamares
    - calamares-settings-debian
  - try_remove:
    - live-boot
    - live-boot-initramfs-tools
    - live-config
    - live-config-systemd
EOF

# Bootloader module
cat > "${CALAMARES_DIR}/modules/bootloader.conf" << 'EOF'
---
efiBootLoader: "grub"
efiBootloaderId: "nubiferos"
grubInstall: "grub-install"
grubMkconfig: "grub-mkconfig"
grubCfg: "/boot/grub/grub.cfg"
grubProbe: "grub-probe"
efiBootMgr: "efibootmgr"
installEFIFallback: true

# Kernel command line parameters
kernelLine: ", with Linux"
fallbackKernelLine: ", with Linux (fallback initramfs)"

# Timeout for bootloader installation (seconds)
timeout: 120

# GRUB installation options for EFI
grubInstallOptions:
  - "--target=x86_64-efi"
  - "--efi-directory=@@ROOT@@/boot/efi"
  - "--bootloader-id=nubiferos"
  - "--no-nvram"
  - "--removable"
  - "--recheck"
  - "--no-floppy"

# GRUB installation options for BIOS
grubPCInstallOptions:
  - "--target=i386-pc"
  - "--recheck"
  - "--no-floppy"

# Use standard chroot mode - Calamares handles device mounting properly
dontChroot: false

# Additional GRUB configuration
grubCfgOptions:
  - "GRUB_ENABLE_CRYPTODISK=y"
  - "GRUB_CMDLINE_LINUX_DEFAULT=\"plymouth.enable=0\""
EOF

# Finished module
cat > "${CALAMARES_DIR}/modules/finished.conf" << 'EOF'
---
# Use 'always' to force restart (removes "continue using live environment" option)
restartNowMode: always
restartNowCommand: "systemctl reboot"
notifyOnFinished: true
EOF

# Displaymanager module
cat > "${CALAMARES_DIR}/modules/displaymanager.conf" << 'EOF'
---
displaymanagers:
  - gdm3
  - gdm
  - lightdm
  - sddm

defaultDesktopEnvironment:
    executable: "gnome-session"
    desktopFile: "gnome"

basicSetup: false
EOF

echo ""
echo "=========================================="
echo "✓ Calamares configuration created!"
echo "=========================================="
echo ""
echo "Configuration location: ${CALAMARES_DIR}"
echo ""
echo "Next steps:"
echo "1. Add logo images to: ${CALAMARES_DIR}/branding/nubiferos/"
echo "2. Customize modules in: ${CALAMARES_DIR}/modules/"
echo "3. Run the build to test"
echo ""
