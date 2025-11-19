# CodeBuild ISO Testing

This directory contains CodeBuild buildspecs for testing NubiferOS ISOs.

## Overview

The testing pipeline:
1. **GitHub Actions** builds ISO
2. **GitHub Actions** uploads ISO to S3
3. **CodeBuild** downloads ISO from S3
4. **CodeBuild** tests ISO locally with QEMU
5. **CodeBuild** reports results

## Files

- **`test-iso-buildspec.yml`** - Test ISO locally with QEMU (RECOMMENDED) ⭐
- **`import-iso-buildspec.yml`** - Old broken ISO import (DON'T USE) ❌
- **`import-iso-buildspec-packer.yml`** - Build AMI with Packer (optional)
- **`deploy-instance-buildspec.yml`** - Deploy test instance

## Quick Start

### 1. Create CodeBuild Project

```bash
aws codebuild create-project \
  --name nubiferos-test-iso \
  --source type=S3,location=nubiferos-iso/buildspec.zip \
  --artifacts type=NO_ARTIFACTS \
  --environment type=LINUX_CONTAINER,image=aws/codebuild/standard:7.0,computeType=BUILD_GENERAL1_LARGE \
  --service-role arn:aws:iam::ACCOUNT:role/CodeBuildServiceRole \
  --buildspec aws-testing/codebuild/test-iso-buildspec.yml
```

### 2. Trigger Build

**Option A: Manually**
```bash
aws codebuild start-build --project-name nubiferos-test-iso
```

**Option B: S3 Event Trigger**
Configure S3 to trigger CodeBuild when ISO is uploaded.

**Option C: GitHub Actions**
Trigger from GitHub Actions after upload.

### 3. View Results

```bash
# Get build status
aws codebuild batch-get-builds --ids <build-id>

# View logs
aws logs tail /aws/codebuild/nubiferos-test-iso --follow
```

## Buildspec Details

### test-iso-buildspec.yml (RECOMMENDED)

**What it does:**
1. Downloads ISO from S3
2. Runs automated pytest tests
3. Boots ISO in QEMU (headless)
4. Verifies boot messages
5. Reports results
6. Cleans up ISO to save space

**Time:** 5-10 minutes

**Cost:** ~$0.05 per test

**Environment:**
- Image: `aws/codebuild/standard:7.0`
- Compute: `BUILD_GENERAL1_LARGE` (8GB RAM, 4 vCPUs)
- Timeout: 15 minutes

**Environment Variables:**
- `ISO_BUCKET` - S3 bucket name (default: nubiferos-iso)
- `ISO_KEY` - S3 key path (default: 1.0/NubiferOS-1.0-amd64.iso)

**Artifacts:**
- `qemu-output.log` - QEMU boot output
- `test-results.xml` - pytest JUnit XML

### import-iso-buildspec-packer.yml (OPTIONAL)

**What it does:**
1. Uses Packer to build AMI
2. Installs NubiferOS components
3. Creates AMI for AWS testing

**Time:** 15-25 minutes

**Cost:** ~$0.10 per build

**Use when:** You need to test in AWS environment

## Configuration

### Environment Variables

Set in CodeBuild project or buildspec:

```yaml
env:
  variables:
    ISO_BUCKET: "your-bucket-name"
    ISO_KEY: "path/to/your.iso"
```

### S3 Bucket Structure

Recommended structure:
```
s3://nubiferos-iso/
├── 1.0/
│   ├── NubiferOS-1.0-amd64.iso
│   └── NubiferOS-1.0-amd64.iso.sha256
├── 1.1/
│   └── NubiferOS-1.1-amd64.iso
└── latest/
    └── NubiferOS-latest.iso  # Symlink or copy
```

### IAM Permissions

CodeBuild service role needs:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::nubiferos-iso",
        "arn:aws:s3:::nubiferos-iso/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    }
  ]
}
```

## Integration with GitHub Actions

### GitHub Actions Workflow

```yaml
name: Build and Test ISO

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Build ISO
        run: sudo ./build-nubiferos.sh
        
      - name: Upload to S3
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        run: |
          aws s3 cp output/NubiferOS-1.0-amd64.iso \
            s3://nubiferos-iso/1.0/NubiferOS-1.0-amd64.iso
          
      - name: Trigger CodeBuild Test
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        run: |
          BUILD_ID=$(aws codebuild start-build \
            --project-name nubiferos-test-iso \
            --query 'build.id' \
            --output text)
          echo "CodeBuild started: $BUILD_ID"
          
          # Wait for build to complete
          aws codebuild wait build-complete --ids $BUILD_ID
          
          # Check result
          STATUS=$(aws codebuild batch-get-builds \
            --ids $BUILD_ID \
            --query 'builds[0].buildStatus' \
            --output text)
          
          if [ "$STATUS" != "SUCCEEDED" ]; then
            echo "❌ CodeBuild test failed"
            exit 1
          fi
          
          echo "✅ CodeBuild test passed"
```

## Monitoring

### CloudWatch Logs

View logs in real-time:
```bash
aws logs tail /aws/codebuild/nubiferos-test-iso --follow
```

### Build History

```bash
# List recent builds
aws codebuild list-builds-for-project \
  --project-name nubiferos-test-iso \
  --max-items 10

# Get build details
aws codebuild batch-get-builds --ids <build-id>
```

### Metrics

View in CloudWatch:
- Build duration
- Success/failure rate
- Cost per build

## Troubleshooting

### ISO Download Fails

**Error:** `Unable to locate credentials`

**Fix:** Check IAM role has S3 permissions

**Error:** `The specified key does not exist`

**Fix:** Verify ISO_BUCKET and ISO_KEY are correct

### QEMU Tests Fail

**Error:** `Could not access KVM kernel module`

**Fix:** This is expected in CodeBuild (no KVM). Tests run without KVM.

**Error:** `qemu-system-x86_64: command not found`

**Fix:** Ensure `apt-get install qemu-system-x86` runs in pre_build

### pytest Fails

**Error:** `ISO not found`

**Fix:** Check ISO downloaded successfully in build phase

**Error:** `Permission denied`

**Fix:** Ensure ISO file is readable (check file permissions)

### Build Timeout

**Error:** `Build timed out`

**Fix:** Increase timeout in CodeBuild project settings (default: 15 min)

## Cost Optimization

### Reduce Build Time

1. **Use larger compute type** - Faster but more expensive
2. **Skip optional tests** - Remove non-critical tests
3. **Parallel testing** - Run tests in parallel (requires code changes)

### Reduce Storage Costs

1. **Delete ISO after test** - Already done in buildspec
2. **Use S3 lifecycle policies** - Auto-delete old ISOs
3. **Compress ISOs** - Use gzip (but slower to download)

### Reduce Compute Costs

1. **Use smaller compute type** - BUILD_GENERAL1_MEDIUM (4GB RAM)
2. **Run tests less frequently** - Only on releases, not every commit
3. **Use spot instances** - Not available for CodeBuild

## Performance

### Build Times

| Phase | Time |
|-------|------|
| Pre-build (install deps) | 1-2 min |
| Download ISO | 1-2 min |
| pytest tests | 2-3 min |
| QEMU boot test | 1 min |
| Post-build | 30 sec |
| **Total** | **5-10 min** |

### Costs

| Resource | Cost |
|----------|------|
| CodeBuild (BUILD_GENERAL1_LARGE) | $0.01/min |
| S3 download | $0.09/GB |
| CloudWatch Logs | $0.50/GB |
| **Total per test** | **~$0.05-0.10** |

## Best Practices

1. ✅ **Test locally first** - Faster and free
2. ✅ **Clean up ISOs** - Save storage costs
3. ✅ **Use environment variables** - Easy configuration
4. ✅ **Monitor build times** - Optimize slow tests
5. ✅ **Set up notifications** - SNS for build failures
6. ✅ **Version your ISOs** - Use semantic versioning in S3 keys
7. ✅ **Archive old ISOs** - S3 lifecycle policies

## Next Steps

1. ✅ Create CodeBuild project
2. ✅ Configure IAM permissions
3. ✅ Test manually
4. ✅ Integrate with GitHub Actions
5. ✅ Set up notifications
6. ✅ Monitor and optimize

## Support

For issues:
1. Check CloudWatch logs
2. Verify IAM permissions
3. Test ISO locally first
4. Check S3 bucket and key

---

**Recommended:** Use `test-iso-buildspec.yml` for fast, cheap ISO testing.
