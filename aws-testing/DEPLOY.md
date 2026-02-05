# Deployment Guide

## Prerequisites

1. **AWS Account** with admin access
2. **AWS CLI** installed and configured
3. **Terraform** installed (v1.0+)

## Step-by-Step Deployment

### 1. Configure AWS Credentials

```bash
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key  
# Default region: us-east-1
# Default output format: json
```

### 2. Initialize Terraform

```bash
cd aws-testing/terraform
terraform init
```

### 3. Review Configuration

Edit `variables.tf` to customize:
- `aws_region` - Your preferred AWS region
- `iso_bucket_name` - Unique S3 bucket name
- `allowed_cidr_blocks` - Your IP address for security

### 4. Plan Deployment

```bash
terraform plan
```

Review the resources that will be created:
- S3 buckets (2)
- IAM roles (3)
- CodeBuild projects (2)
- CodePipeline (1)
- Security group (1)

### 5. Deploy Infrastructure

```bash
terraform apply
# Type 'yes' to confirm
```

**Duration:** ~2-3 minutes

### 6. Upload ISO

After deployment completes:

```bash
# From project root
aws s3 cp output/nubiferos-1.0-amd64.iso \
    s3://<your-bucket-name>/nubiferos-latest.iso
```

### 7. Monitor Pipeline

```bash
# Watch pipeline status
aws codepipeline get-pipeline-state \
    --name nubiferos-test-pipeline

# View build logs
aws logs tail /aws/codebuild/nubiferos-import-iso --follow
```

### 8. Connect to Test Instance

After pipeline completes (~40 minutes):

```bash
# Get instance IP
INSTANCE_IP=$(aws ec2 describe-instances \
    --filters "Name=tag:Purpose,Values=nubiferos-test" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)

echo "Connect to: https://${INSTANCE_IP}:8443"
echo "Username: live"
echo "Password: (see docs/guides/LIVE_USER_EXPLANATION.md)"
```

## Estimated Costs

- **S3 Storage:** ~$0.50/month (20GB ISO)
- **CodeBuild:** ~$0.10/build
- **EC2 (t3.large):** ~$0.08/hour
- **Data Transfer:** ~$0.09/GB

**Total per test:** ~$2-3 (2-hour session)

## Cleanup

### Terminate Test Instance

```bash
aws ec2 terminate-instances --instance-ids $(aws ec2 describe-instances \
    --filters "Name=tag:Purpose,Values=nubiferos-test" \
    --query 'Reservations[0].Instances[0].InstanceId' \
    --output text)
```

### Destroy Infrastructure

```bash
cd aws-testing/terraform
terraform destroy
# Type 'yes' to confirm
```

## Troubleshooting

### Terraform Init Fails

```bash
# Clear cache
rm -rf .terraform
terraform init
```

### AWS Credentials Not Found

```bash
# Check credentials
aws sts get-caller-identity

# Reconfigure if needed
aws configure
```

### S3 Bucket Name Already Exists

Edit `terraform/variables.tf` and change `iso_bucket_name` to something unique.

### Pipeline Stuck

```bash
# Check pipeline status
aws codepipeline get-pipeline-execution-summary \
    --pipeline-name nubiferos-test-pipeline

# Retry failed stage
aws codepipeline retry-stage-execution \
    --pipeline-name nubiferos-test-pipeline \
    --stage-name ImportISO \
    --pipeline-execution-id <execution-id>
```

## Next Steps

1. ✅ Deploy infrastructure
2. ✅ Upload ISO
3. ✅ Monitor pipeline
4. ✅ Connect via NICE DCV
5. ✅ Test your ISO!
