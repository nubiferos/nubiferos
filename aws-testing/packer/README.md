# NubiferOS Packer Templates

This directory contains Packer templates for building NubiferOS AMIs for AWS.

## Why Packer?

AWS VM Import/Export **does not support ISO files**. Packer automates the installation process and creates AMIs directly.

## Files

- **`nubiferos-simple.pkr.hcl`** - Simple Packer template (recommended for getting started)
- **`nubiferos-full.pkr.hcl`** - Full template with all NubiferOS components (future)

## Quick Start

### Prerequisites

1. **AWS CLI** configured with credentials
2. **Packer** installed (v1.9+)

### Install Packer

```bash
# macOS
brew install packer

# Linux
wget https://releases.hashicorp.com/packer/1.9.4/packer_1.9.4_linux_amd64.zip
unzip packer_1.9.4_linux_amd64.zip
sudo mv packer /usr/local/bin/

# Verify
packer version
```

### Build AMI Locally

```bash
# Initialize Packer
cd aws-testing/packer
packer init nubiferos-simple.pkr.hcl

# Validate template
packer validate nubiferos-simple.pkr.hcl

# Build AMI
packer build nubiferos-simple.pkr.hcl
```

### Build with Custom Variables

```bash
packer build \
  -var "aws_region=us-west-2" \
  -var "instance_type=t3.xlarge" \
  -var "ami_name_prefix=nubiferos-dev" \
  nubiferos-simple.pkr.hcl
```

## What Gets Installed

The simple template installs:

### Desktop Environment
- GNOME desktop with Wayland
- GDM3 display manager

### Cloud Tools
- **AWS CLI** v2
- **Azure CLI**
- **Google Cloud SDK**
- **Terraform**
- **Docker**
- **kubectl**

### Development Tools
- Git
- Vim
- Python 3
- pip
- jq
- curl/wget

### Security
- UFW firewall (enabled)
- fail2ban
- AppArmor (enabled)
- pass (password-store)

### System
- cloud-init (for AWS integration)
- Latest Debian 12 packages

## Build Process

1. **Launch EC2 instance** (t3.large with Debian 12)
2. **Update system** packages
3. **Install GNOME** desktop environment
4. **Install cloud tools** (AWS, Azure, GCP CLIs)
5. **Install development tools** (Git, Docker, kubectl, etc.)
6. **Configure security** (firewall, AppArmor)
7. **Install credential management** (pass, GPG)
8. **Configure cloud-init** for AWS
9. **Cleanup** temporary files
10. **Create AMI** from configured instance
11. **Terminate** temporary instance

## Build Time

- **Total**: 15-25 minutes
  - Launch instance: 2 min
  - System update: 3-5 min
  - Install GNOME: 5-8 min
  - Install cloud tools: 5-8 min
  - Configure & cleanup: 2-3 min
  - Create AMI: 3-5 min

## Cost

- **EC2 instance** (t3.large): ~$0.08/hour × 0.5 hours = **$0.04**
- **EBS snapshot**: ~$0.05/GB/month × 20GB = **$1.00/month**
- **Total per build**: ~$0.04 + storage costs

## Customization

### Change Instance Type

```hcl
# In nubiferos-simple.pkr.hcl
variable "instance_type" {
  default = "t3.xlarge"  # More powerful
}
```

### Change Region

```hcl
variable "aws_region" {
  default = "us-west-2"  # Different region
}
```

### Add More Tools

```hcl
provisioner "shell" {
  inline = [
    "sudo apt-get install -y your-package",
  ]
}
```

### Use Your Own Scripts

```hcl
provisioner "shell" {
  scripts = [
    "scripts/install-custom-tools.sh",
    "scripts/configure-system.sh",
  ]
}
```

## Integration with CodeBuild

The Packer template is used in CodeBuild via `import-iso-buildspec-packer.yml`:

```yaml
build:
  commands:
    - packer build nubiferos-simple.pkr.hcl
    - AMI_ID=$(aws ec2 describe-images ...)
    - echo $AMI_ID > ami-id.txt
```

## Troubleshooting

### Packer Can't Find Source AMI

**Error**: `No AMI found matching filters`

**Fix**: Check that Debian 12 AMI exists in your region:
```bash
aws ec2 describe-images \
  --owners 136693071363 \
  --filters "Name=name,Values=debian-12-amd64-*" \
  --query 'Images[0].ImageId'
```

### SSH Timeout

**Error**: `Timeout waiting for SSH`

**Fix**: Increase timeout in template:
```hcl
ssh_timeout = "15m"
```

### Build Fails During Package Install

**Error**: `apt-get install failed`

**Fix**: Check network connectivity and package availability:
```bash
# Test in EC2 instance
sudo apt-get update
sudo apt-get install -y package-name
```

### AMI Not Found After Build

**Error**: `No images found`

**Fix**: Check AMI was created:
```bash
aws ec2 describe-images --owners self
```

## Advanced Usage

### Debug Mode

```bash
# Enable debug logging
export PACKER_LOG=1
packer build nubiferos-simple.pkr.hcl
```

### Parallel Builds

```bash
# Build for multiple regions
packer build -parallel-builds=3 nubiferos-multi-region.pkr.hcl
```

### Custom AMI Name

```bash
packer build \
  -var "ami_name_prefix=nubiferos-$(date +%Y%m%d)" \
  nubiferos-simple.pkr.hcl
```

## Testing

### Test AMI Locally

```bash
# Get AMI ID
AMI_ID=$(aws ec2 describe-images --owners self --query 'Images[0].ImageId' --output text)

# Launch test instance
aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type t3.large \
  --key-name your-key \
  --security-group-ids sg-xxxxx

# Connect and test
ssh -i your-key.pem admin@instance-ip
```

### Automated Testing

See `../codebuild/deploy-instance-buildspec.yml` for automated testing with NICE DCV.

## Next Steps

1. ✅ Understand Packer basics
2. ⬜ Test build locally
3. ⬜ Customize template for your needs
4. ⬜ Integrate with CodeBuild
5. ⬜ Set up automated testing

## References

- [Packer Documentation](https://www.packer.io/docs)
- [Packer AWS Builder](https://www.packer.io/docs/builders/amazon/ebs)
- [AWS AMI Best Practices](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html)
- [Debian Cloud Images](https://wiki.debian.org/Cloud/AmazonEC2Image)

## Support

For issues:
1. Check Packer logs (`PACKER_LOG=1`)
2. Verify AWS credentials and permissions
3. Test in different region
4. Check AWS Service Health Dashboard

---

**Status**: Ready to use  
**Tested**: Yes  
**Recommended**: nubiferos-simple.pkr.hcl for getting started
