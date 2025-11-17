# AWS Testing Pipeline

This directory contains the AWS infrastructure for automated ISO testing using CodePipeline, CodeBuild, and EC2 with NICE DCV remote desktop.

## Overview

The pipeline automatically:
1. Detects new ISO uploads to S3
2. Converts ISO to AMI using AWS VM Import
3. Launches EC2 instance from AMI
4. Installs NICE DCV for remote desktop access
5. Provides connection URL for GUI testing

## Architecture

```
GitHub Actions (Build ISO)
    ↓
S3 Bucket (nubiferos-iso-builds)
    ↓ (S3 Event Trigger)
CodePipeline (nubiferos-test-pipeline)
    ↓
Stage 1: Import ISO to AMI
    - CodeBuild: import-iso-buildspec.yml
    - Uses AWS VM Import/Export
    - Outputs AMI ID
    ↓
Stage 2: Deploy Test Instance
    - CodeBuild: deploy-instance-buildspec.yml
    - Launches EC2 from AMI
    - Installs NICE DCV
    - Outputs connection URL
```

## Directory Structure

```
aws-testing/
├── README.md                      # This file
├── terraform/                     # Infrastructure as Code
│   ├── main.tf                   # Main Terraform configuration
│   ├── variables.tf              # Input variables
│   ├── outputs.tf                # Output values
│   └── backend.tf                # S3 backend configuration
├── codebuild/
│   ├── import-iso-buildspec.yml  # Stage 1: ISO → AMI
│   ├── deploy-instance-buildspec.yml  # Stage 2: Launch EC2
│   └── scripts/
│       ├── import-iso.sh         # ISO import script
│       ├── wait-for-import.sh    # Wait for import completion
│       └── deploy-instance.sh    # EC2 deployment script
├── user-data/
│   └── install-nice-dcv.sh       # NICE DCV installation script
├── policies/
│   ├── vmimport-role.json        # VM Import service role
│   └── vmimport-trust.json       # Trust policy
└── docs/
    ├── SETUP.md                  # Setup instructions
    └── USAGE.md                  # Usage guide
```

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **AWS CLI** configured with credentials
3. **Terraform** installed (v1.0+)
4. **S3 Bucket** for ISO storage (created by Terraform)
5. **VM Import/Export** service role (created by Terraform)

## Quick Start

### 1. Deploy Infrastructure

```bash
cd aws-testing/terraform
terraform init
terraform plan
terraform apply
```

This creates:
- S3 bucket for ISO storage
- CodePipeline and CodeBuild projects
- IAM roles and policies
- VM Import service role
- Security groups for EC2

### 2. Upload ISO

The GitHub Actions workflow automatically uploads ISOs to S3 after build.

Or manually:
```bash
aws s3 cp output/nubiferos-1.0-amd64.iso \
    s3://nubiferos-iso-builds/nubiferos-1.0-amd64.iso
```

### 3. Monitor Pipeline

```bash
# Watch pipeline execution
aws codepipeline get-pipeline-state \
    --name nubiferos-test-pipeline

# View CodeBuild logs
aws logs tail /aws/codebuild/nubiferos-import-iso --follow
```

### 4. Connect to Test Instance

After pipeline completes, get connection URL:
```bash
# Get instance public IP
aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=nubiferos-test" \
    --query 'Reservations[0].Instances[0].PublicIpAddress'

# Connect via NICE DCV
# URL: https://<instance-ip>:8443
# Username: live
# Password: live
```

## Pipeline Stages

### Stage 1: Import ISO to AMI

**Duration:** 30-60 minutes

**Process:**
1. Download ISO from S3
2. Create VM Import task
3. Wait for import completion
4. Tag AMI with metadata
5. Output AMI ID to SSM Parameter Store

**Buildspec:** `codebuild/import-iso-buildspec.yml`

### Stage 2: Deploy Test Instance

**Duration:** 5-10 minutes

**Process:**
1. Read AMI ID from SSM Parameter Store
2. Launch EC2 instance from AMI
3. Install NICE DCV via user data
4. Configure security group
5. Output connection URL

**Buildspec:** `codebuild/deploy-instance-buildspec.yml`

## Configuration

### Environment Variables

Set in `terraform/variables.tf`:

- `aws_region` - AWS region (default: us-east-1)
- `iso_bucket_name` - S3 bucket for ISOs
- `instance_type` - EC2 instance type (default: t3.large)
- `allowed_cidr_blocks` - IP ranges for NICE DCV access

### Cost Optimization

**Estimated Costs:**
- S3 Storage: ~$0.50/month (20GB ISO)
- CodeBuild: ~$0.10/build (2 builds)
- EC2 (t3.large): ~$0.08/hour
- Data Transfer: ~$0.09/GB

**Total per test:** ~$2-3 (assuming 2-hour test session)

**Auto-shutdown:**
- Instances auto-terminate after 4 hours
- Can be extended via tag

## Troubleshooting

### ISO Import Fails

```bash
# Check import task status
aws ec2 describe-import-image-tasks

# View detailed error
aws ec2 describe-import-image-tasks \
    --import-task-ids import-ami-xxxxx
```

Common issues:
- ISO format not supported → Ensure ISO is bootable
- S3 permissions → Check vmimport role
- Disk size too large → Reduce ISO size

### NICE DCV Won't Connect

```bash
# Check instance status
aws ec2 describe-instance-status \
    --instance-ids i-xxxxx

# View user data logs
aws ssm start-session --target i-xxxxx
sudo cat /var/log/cloud-init-output.log
```

Common issues:
- Security group → Ensure port 8443 is open
- NICE DCV not started → Check systemctl status dcvserver
- Firewall → Check ufw status

## Cleanup

### Terminate Test Instance

```bash
# Find test instances
aws ec2 describe-instances \
    --filters "Name=tag:Purpose,Values=nubiferos-test"

# Terminate
aws ec2 terminate-instances --instance-ids i-xxxxx
```

### Delete AMI

```bash
# Deregister AMI
aws ec2 deregister-image --image-id ami-xxxxx

# Delete snapshot
aws ec2 delete-snapshot --snapshot-id snap-xxxxx
```

### Destroy Infrastructure

```bash
cd aws-testing/terraform
terraform destroy
```

## Security Considerations

1. **NICE DCV Access** - Restricted to specific IP ranges
2. **S3 Bucket** - Private, encrypted at rest
3. **IAM Roles** - Least privilege access
4. **Security Groups** - Only necessary ports open
5. **Auto-termination** - Instances don't run indefinitely

## Next Steps

1. Review `docs/SETUP.md` for detailed setup instructions
2. Configure AWS credentials
3. Deploy infrastructure with Terraform
4. Test pipeline with sample ISO
5. Access instance via NICE DCV

## Support

For issues or questions:
- Check `docs/USAGE.md` for common scenarios
- Review CloudWatch logs for errors
- Check AWS Service Health Dashboard

## License

Same as parent project
