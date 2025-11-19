# Packer Implementation Guide for NubiferOS

## Overview

This guide explains how to use HashiCorp Packer to automate NubiferOS installation and AMI creation for AWS testing.

## What is Packer?

Packer is an open-source tool for creating identical machine images for multiple platforms from a single source configuration.

**For NubiferOS:**
- Automates installation from ISO
- Creates AWS AMI directly
- Reproducible builds
- No manual intervention

## Architecture

```
GitHub Actions Build
  ↓
ISO uploaded to S3
  ↓
CodeBuild runs Packer
  ↓
Packer:
  1. Launches temporary EC2 instance
  2. Attaches ISO as virtual CD
  3. Boots from ISO
  4. Runs automated installation (preseed)
  5. Configures system
  6. Creates AMI
  7. Terminates instance
  ↓
AMI ready for testing
```

## Prerequisites

1. **Packer** installed (v1.8+)
2. **AWS CLI** configured
3. **S3 bucket** with ISO
4. **Preseed file** for automated installation

## Implementation Steps

### Step 1: Create Preseed File

Create `installer/preseed/nubiferos-aws.cfg`:

```bash
# Debian preseed file for automated NubiferOS installation

# Localization
d-i debian-installer/locale string en_US.UTF-8
d-i keyboard-configuration/xkb-keymap select us

# Network configuration
d-i netcfg/choose_interface select auto
d-i netcfg/get_hostname string nubiferos
d-i netcfg/get_domain string local

# Mirror settings
d-i mirror/country string manual
d-i mirror/http/hostname string deb.debian.org
d-i mirror/http/directory string /debian
d-i mirror/http/proxy string

# Account setup
d-i passwd/root-login boolean false
d-i passwd/user-fullname string NubiferOS User
d-i passwd/username string nubifer
d-i passwd/user-password password nubifer123
d-i passwd/user-password-again password nubifer123
d-i user-setup/allow-password-weak boolean true

# Clock and time zone
d-i clock-setup/utc boolean true
d-i time/zone string UTC

# Partitioning
d-i partman-auto/method string regular
d-i partman-auto/choose_recipe select atomic
d-i partman/confirm_write_new_label boolean true
d-i partman/choose_partition select finish
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true

# Package selection
tasksel tasksel/first multiselect standard, gnome-desktop
d-i pkgsel/include string openssh-server cloud-init
d-i pkgsel/upgrade select full-upgrade

# Boot loader
d-i grub-installer/only_debian boolean true
d-i grub-installer/bootdev string default

# Finish installation
d-i finish-install/reboot_in_progress note
```

### Step 2: Create Packer Template

Create `aws-testing/packer/nubiferos.pkr.hcl`:

```hcl
# Packer template for NubiferOS AMI creation

packer {
  required_plugins {
    amazon = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

# Variables
variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "iso_url" {
  type        = string
  description = "S3 URL to NubiferOS ISO"
}

variable "ami_name" {
  type    = string
  default = "nubiferos-{{timestamp}}"
}

# Source configuration
source "amazon-ebs" "nubiferos" {
  region        = var.aws_region
  instance_type = "t3.large"
  
  # Use Debian 12 as base for installation
  source_ami_filter {
    filters = {
      name                = "debian-12-amd64-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["136693071363"] # Debian official
  }
  
  ssh_username = "admin"
  ami_name     = var.ami_name
  
  tags = {
    Name        = "NubiferOS"
    Version     = "1.0"
    BuildDate   = "{{timestamp}}"
    Purpose     = "Testing"
  }
}

# Build configuration
build {
  sources = ["source.amazon-ebs.nubiferos"]
  
  # Download ISO
  provisioner "shell" {
    inline = [
      "echo 'Downloading NubiferOS ISO...'",
      "wget -O /tmp/nubiferos.iso ${var.iso_url}",
    ]
  }
  
  # Mount ISO and extract
  provisioner "shell" {
    inline = [
      "sudo mkdir -p /mnt/iso",
      "sudo mount -o loop /tmp/nubiferos.iso /mnt/iso",
      "echo 'ISO mounted successfully'",
    ]
  }
  
  # Run NubiferOS installation scripts
  provisioner "shell" {
    scripts = [
      "scripts/install-nubiferos.sh",
      "scripts/configure-cloud-init.sh",
      "scripts/cleanup.sh"
    ]
  }
  
  # Unmount ISO
  provisioner "shell" {
    inline = [
      "sudo umount /mnt/iso",
      "sudo rm /tmp/nubiferos.iso",
    ]
  }
}
```

### Step 3: Create Installation Script

Create `aws-testing/packer/scripts/install-nubiferos.sh`:

```bash
#!/bin/bash
# Install NubiferOS components on base Debian system

set -e

echo "Installing NubiferOS components..."

# Copy files from mounted ISO
sudo cp -r /mnt/iso/nubiferos/* /opt/nubiferos/

# Run NubiferOS post-install scripts
cd /opt/nubiferos/installer/scripts
sudo ./post-install.sh

# Install cloud tools
sudo ./install-cloud-tools.sh

# Configure GNOME
sudo ./configure-desktop.sh

# Install IDE plugins
sudo ./install-ide-plugins.sh

# Configure security
sudo ./apply-security-hardening.sh

echo "NubiferOS installation complete!"
```

### Step 4: Update CodeBuild Buildspec

Update `aws-testing/codebuild/import-iso-buildspec.yml`:

```yaml
version: 0.2

phases:
  pre_build:
    commands:
      - echo "Installing Packer..."
      - wget https://releases.hashicorp.com/packer/1.9.4/packer_1.9.4_linux_amd64.zip
      - unzip packer_1.9.4_linux_amd64.zip
      - sudo mv packer /usr/local/bin/
      - packer version
      
  build:
    commands:
      - echo "Building NubiferOS AMI with Packer..."
      - cd aws-testing/packer
      
      - |
        packer build \
          -var "iso_url=s3://$ISO_BUCKET/nubiferos-latest.iso" \
          -var "aws_region=$AWS_REGION" \
          nubiferos.pkr.hcl
      
      - echo "Retrieving AMI ID..."
      - |
        AMI_ID=$(aws ec2 describe-images \
          --owners self \
          --filters "Name=name,Values=nubiferos-*" \
          --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
          --output text)
      
      - echo "AMI ID: $AMI_ID"
      - echo $AMI_ID > ami-id.txt
      
      - echo "Storing AMI ID in SSM..."
      - |
        aws ssm put-parameter \
          --name "/nubiferos/latest-ami-id" \
          --value "$AMI_ID" \
          --type String \
          --overwrite

artifacts:
  files:
    - ami-id.txt
```

### Step 5: Test Locally

Before deploying to CodeBuild, test Packer locally:

```bash
# Set AWS credentials
export AWS_ACCESS_KEY_ID=your_key
export AWS_SECRET_ACCESS_KEY=your_secret
export AWS_REGION=us-east-1

# Upload ISO to S3
aws s3 cp output/nubiferos-1.0-amd64.iso s3://your-bucket/

# Run Packer
cd aws-testing/packer
packer build \
  -var "iso_url=s3://your-bucket/nubiferos-1.0-amd64.iso" \
  nubiferos.pkr.hcl
```

## Alternative: Simpler Approach

If full Packer setup is too complex, use a hybrid approach:

### Hybrid Approach: Base AMI + Scripts

1. Start with Debian 12 AMI
2. Run NubiferOS installation scripts
3. Create AMI from configured instance

**Packer template (simplified):**

```hcl
source "amazon-ebs" "nubiferos" {
  region        = "us-east-1"
  instance_type = "t3.large"
  
  # Start with Debian 12
  source_ami_filter {
    filters = {
      name = "debian-12-amd64-*"
    }
    most_recent = true
    owners      = ["136693071363"]
  }
  
  ssh_username = "admin"
  ami_name     = "nubiferos-{{timestamp}}"
}

build {
  sources = ["source.amazon-ebs.nubiferos"]
  
  # Download and run NubiferOS installer
  provisioner "shell" {
    inline = [
      "wget https://github.com/nubiferos/nubiferos/archive/main.tar.gz",
      "tar xzf main.tar.gz",
      "cd nubiferos-main",
      "sudo ./installer/scripts/post-install.sh",
    ]
  }
}
```

## Estimated Timeline

- **Setup Packer**: 2-4 hours
- **Create preseed file**: 1-2 hours
- **Test locally**: 1-2 hours
- **Integrate with CodeBuild**: 1 hour
- **Total**: 1 day

## Build Time

- **Packer build**: 15-25 minutes
  - Launch instance: 2 min
  - Install packages: 10-15 min
  - Configure system: 3-5 min
  - Create AMI: 3-5 min

Much faster than ISO import (which doesn't work anyway).

## Cost

- **EC2 instance** (t3.large): ~$0.08/hour × 0.5 hours = $0.04
- **EBS snapshots**: ~$0.05/GB/month
- **Total per build**: ~$0.10

## Benefits

✅ **Automated**: No manual steps  
✅ **Fast**: 15-25 minutes vs 30-60 minutes  
✅ **Reliable**: Industry-standard tool  
✅ **Reproducible**: Same result every time  
✅ **Multi-cloud**: Can build for Azure, GCP too  
✅ **Well-documented**: Extensive community support  

## Next Steps

1. ⬜ Create preseed file
2. ⬜ Create Packer template
3. ⬜ Create installation scripts
4. ⬜ Test locally
5. ⬜ Update CodeBuild buildspec
6. ⬜ Deploy and test pipeline

## References

- [Packer Documentation](https://www.packer.io/docs)
- [Packer AWS Builder](https://www.packer.io/docs/builders/amazon/ebs)
- [Debian Preseed](https://www.debian.org/releases/stable/amd64/apb.html)
- [AWS AMI Creation](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html)

---

**Recommendation**: Start with the simplified hybrid approach (Debian base + scripts), then enhance with full ISO installation if needed.
