# NubiferOS Build System

This directory contains the build system for creating NubiferOS ISO images.

## Build Process Overview

The build process consists of several stages:

1. **Download Debian Base** (`download-debian.sh`) ✅
2. **Extract and Bootstrap** (`extract-debian.sh`) ✅
3. **Install Cloud Tools** (`install-cloud-tools.sh`) - Next
4. **Customize System** (`customize-system.sh`)
5. **Create ISO** (`build-iso.sh`)

## Prerequisites

### System Requirements
- Debian 12 or Ubuntu 22.04+ (host system)
- 20GB free disk space
- 4GB RAM minimum (8GB recommended)
- Internet connection
- Root/sudo access

### Required Packages
```bash
sudo apt-get update
sudo apt-get install -y \
    debootstrap squashfs-tools xorriso \
    grub-pc-bin grub-efi-amd64-bin \
    mtools dosfstools isolinux syslinux-efi \
    wget curl gnupg rsync
```

## Quick Start

```bash
# 1. Download Debian base
./build/download-debian.sh

# 2. Extract and bootstrap (requires sudo)
sudo ./build/extract-debian.sh

# 3-5. Continue with remaining scripts...
```

## Files

### config.sh
Main build configuration file containing:
- Distribution information (name, version, codename)
- Base distribution settings (Debian/Ubuntu)
- Security configuration
- Component versions
- Package lists
- Build paths and options

### build-iso.sh (To be implemented)
Master build script that orchestrates the ISO creation process:
1. Downloads and verifies base ISO
2. Extracts and customizes filesystem
3. Applies security hardening
4. Installs cloud tools
5. Installs CloudOS components
6. Configures desktop environment
7. Creates bootable ISO

### install-cloud-tools.sh (To be implemented)
Script to install all cloud CLI tools:
- AWS tools (aws-cli, sam-cli, eksctl, cdk, etc.)
- Azure tools (az)
- GCP tools (gcloud)
- IaC tools (Terraform, Pulumi, Ansible)
- Container tools (Docker, kubectl, Helm, k9s)

### customize-system.sh (To be implemented)
Script to customize the base system:
- Install CloudOS components
- Configure desktop environment
- Apply CloudOS branding
- Set up systemd services
- Configure security policies

## Usage

### Basic Build

```bash
# Source the configuration
source build/config.sh

# Initialize build environment
init_config

# Run the build (to be implemented)
sudo ./build/build-iso.sh
```

### Custom Build

Edit `config.sh` to customize:
- Base distribution version
- Desktop environment
- Security settings
- Component versions
- Package selections

### Build Options

Set environment variables before building:
```bash
export ENABLE_DEBUG=true
export CLEAN_BUILD=true
export VERIFY_CHECKSUMS=true
export SIGN_ISO=true
```

## Build Process

1. **Initialization**
   - Validate configuration
   - Create build directories
   - Set up logging

2. **Base System**
   - Download Debian/Ubuntu base ISO
   - Verify GPG signature
   - Extract filesystem using debootstrap

3. **Security Hardening**
   - Configure AppArmor profiles
   - Set kernel parameters
   - Install and configure fail2ban
   - Set up firewall rules
   - Enable automatic updates

4. **Cloud Tools Installation**
   - Install AWS CLI tools
   - Install Azure CLI tools
   - Install GCP CLI tools
   - Install IaC tools
   - Install container tools

5. **CloudOS Components**
   - Build and install credential manager
   - Build and install context manager
   - Build and install resource viewer
   - Install context indicator

6. **Desktop Configuration**
   - Install GNOME/KDE
   - Apply CloudOS theme
   - Configure extensions/widgets
   - Set up shell integration

7. **ISO Creation**
   - Create squashfs filesystem
   - Configure bootloader (GRUB)
   - Generate ISO image
   - Create checksums
   - Sign ISO (optional)

## Build Requirements

### System Requirements
- Debian 12 or Ubuntu 22.04 LTS
- 20GB free disk space
- 4GB RAM minimum (8GB recommended)
- Internet connection

### Build Dependencies
```bash
sudo apt-get install -y \
    debootstrap \
    squashfs-tools \
    xorriso \
    grub-pc-bin \
    grub-efi-amd64-bin \
    mtools \
    dosfstools \
    isolinux \
    syslinux-efi \
    python3 \
    python3-pip \
    nodejs \
    npm
```

## Output

Build artifacts are created in:
- `output/`: Final ISO image and checksums
- `iso/`: Temporary build workspace
- `logs/`: Build logs with timestamps

## Troubleshooting

### Build Fails

Check the log file in `logs/` for detailed error messages.

Common issues:
- Insufficient disk space
- Missing dependencies
- Network connectivity issues
- Permission errors (run with sudo)

### Clean Build

Remove all build artifacts:
```bash
sudo rm -rf iso/ output/
```

### Verify ISO

```bash
# Verify checksum
sha256sum -c output/CloudOS-1.0-x86_64.iso.sha256

# Verify GPG signature (if signed)
gpg --verify output/CloudOS-1.0-x86_64.iso.sig output/CloudOS-1.0-x86_64.iso
```

## Configuration Reference

See `config.sh` for all available configuration options.

Key configuration sections:
- Distribution Information
- Base Distribution Settings
- Desktop Environment
- Security Configuration
- Build Paths
- Component Versions
- Package Lists
- Build Options
