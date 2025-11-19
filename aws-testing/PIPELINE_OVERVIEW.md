# NubiferOS CI/CD Pipeline Overview

## Quick Summary

**GitHub Actions builds and tests → S3 stores ISOs → CodeBuild creates AMIs**

## The Pipeline

### 1. GitHub Actions: Build & Test (Primary)

**File**: `.github/workflows/build-iso.yml`

**Triggers**:
- Push to `main` or `develop`
- Pull requests
- Release tags (`v*`)
- Manual workflow dispatch

**What It Does**:
```
Build ISO (30-40 min)
  ↓
Run Tests (2-3 min)
  ├─ Format validation ✅
  ├─ Size check ✅
  └─ Boot test with QEMU/KVM ✅
  ↓
Upload to S3 (only if tests pass)
  ├─ Versioned: s3://nubiferos-iso/1.0/nubiferos-1.0-20250119-abc123.iso
  └─ Latest: s3://nubiferos-iso/nubiferos-latest.iso
  ↓
Trigger CodeBuild (on release tags only)
```

**Key Features**:
- ✅ Full KVM support for fast boot testing
- ✅ Only uploads validated ISOs
- ✅ Creates "latest" symlink for easy access
- ✅ Automatic versioning with timestamps
- ✅ Triggers AMI creation on releases

### 2. AWS CodeBuild: Validate & Create AMI (Secondary)

**Files**: 
- `aws-testing/codebuild/test-iso-buildspec.yml` (validation)
- `aws-testing/codebuild/import-iso-buildspec-packer.yml` (AMI creation)

**Triggers**:
- Automatically by GitHub Actions (on release tags)
- Manually via AWS Console or CLI

**What It Does**:
```
Download ISO from S3
  ↓
Run Validation Tests
  ├─ Format validation ✅
  ├─ Size check ✅
  └─ Boot test (kernel extraction) ✅
  ↓
Create AMI with Packer (optional)
  ├─ Boot ISO in EC2
  ├─ Install to disk
  ├─ Create AMI snapshot
  └─ Publish to AMI catalog
```

**Key Features**:
- ✅ Validates ISO from S3 (smoke test)
- ✅ Creates deployable AWS AMI
- ✅ No KVM needed (uses kernel extraction)
- ✅ Automatic on release tags

## S3 Structure

```
s3://nubiferos-iso/
├── nubiferos-latest.iso              ← Always points to newest build
├── nubiferos-latest.iso.sha256       ← Checksum for latest
├── latest-version.txt                ← Version number of latest
│
├── 1.0/                              ← Version directory
│   ├── nubiferos-1.0-20250119-abc123.iso
│   ├── SHA256SUMS-abc123
│   └── MD5SUMS-abc123
│
└── 1.1/                              ← Next version
    ├── nubiferos-1.1-20250120-def456.iso
    ├── SHA256SUMS-def456
    └── MD5SUMS-def456
```

## Usage Scenarios

### Scenario 1: Development Build

```bash
# Push to develop branch
git push origin develop

# GitHub Actions will:
# 1. Build ISO
# 2. Run tests
# 3. Upload to S3 as nubiferos-latest.iso
# 4. NOT trigger AMI creation
```

### Scenario 2: Release Build

```bash
# Tag a release
git tag v1.0
git push origin v1.0

# GitHub Actions will:
# 1. Build ISO
# 2. Run tests
# 3. Upload to S3 (versioned + latest)
# 4. Trigger CodeBuild for AMI creation

# CodeBuild will:
# 1. Download ISO from S3
# 2. Validate it
# 3. Create AWS AMI
# 4. Publish AMI for deployment
```

### Scenario 3: Manual Testing

```bash
# Download latest ISO
aws s3 cp s3://nubiferos-iso/nubiferos-latest.iso .

# Verify checksum
aws s3 cp s3://nubiferos-iso/nubiferos-latest.iso.sha256 .
sha256sum -c nubiferos-latest.iso.sha256

# Test locally
qemu-system-x86_64 -cdrom nubiferos-latest.iso -m 4096 -enable-kvm
```

### Scenario 4: Download Specific Version

```bash
# List available versions
aws s3 ls s3://nubiferos-iso/ --recursive | grep .iso

# Download specific version
aws s3 cp s3://nubiferos-iso/1.0/nubiferos-1.0-20250119-abc123.iso .
```

## Testing Strategy

### GitHub Actions (Primary Testing)
- **Format validation**: Checks ISO 9660 signature
- **Size validation**: Ensures 1-10GB range
- **Boot test**: Full QEMU boot with KVM (fast!)
- **Result**: Only validated ISOs reach S3

### CodeBuild (Secondary Validation)
- **Format validation**: Re-checks ISO format
- **Size validation**: Re-checks size
- **Boot test**: Kernel extraction method (no KVM)
- **Result**: Confirms S3 upload succeeded

### Why Two Layers?

1. **GitHub Actions** = Definitive test (has KVM, full boot)
2. **CodeBuild** = Smoke test (validates S3 upload, creates AMI)

If GitHub Actions tests pass, the ISO is good. CodeBuild just confirms it survived the S3 upload.

## Cost Estimate

### GitHub Actions
- **Build time**: 30-40 minutes
- **Cost**: Free (included in GitHub)

### AWS CodeBuild
- **Validation**: 5-10 minutes (~$0.05)
- **AMI creation**: 20-30 minutes (~$0.20)
- **Total per release**: ~$0.25

### S3 Storage
- **ISO size**: ~3-4 GB
- **Storage cost**: ~$0.10/month per ISO
- **Transfer cost**: ~$0.09/GB download

## Monitoring

### GitHub Actions
- View workflow runs: https://github.com/YOUR_ORG/nubiferOS/actions
- Check build logs in real-time
- Get notifications on failures

### AWS CodeBuild
- View builds: AWS Console → CodeBuild → Build History
- Check logs in CloudWatch
- Set up SNS notifications for build status

### S3
- View files: AWS Console → S3 → nubiferos-iso
- Check access logs
- Monitor download metrics

## Troubleshooting

### Build Fails in GitHub Actions
1. Check the workflow logs
2. Look for disk space issues (common)
3. Verify dependencies are installed
4. Check build script errors

### Tests Fail in GitHub Actions
1. Check pytest output
2. Boot test failures usually mean ISO is broken
3. Format/size failures mean build issue
4. Re-run the workflow (sometimes transient)

### Upload to S3 Fails
1. Check AWS credentials (OIDC)
2. Verify IAM role permissions
3. Check S3 bucket exists
4. Verify bucket region matches

### CodeBuild Fails
1. Check CodeBuild logs in CloudWatch
2. Verify ISO exists in S3
3. Check IAM role permissions
4. Verify buildspec is correct

### AMI Creation Fails
1. Check Packer logs
2. Verify EC2 permissions
3. Check VPC/subnet configuration
4. Verify ISO boots correctly

## Next Steps

### Immediate
- ✅ GitHub Actions workflow is ready
- ✅ S3 structure is defined
- ✅ Testing strategy is clear

### Short Term
- Set up CodeBuild project for AMI creation
- Configure IAM roles and permissions
- Test the full pipeline end-to-end

### Long Term
- Implement installer-only ISO (from spec)
- Add unattended installation testing
- Create AMI distribution pipeline
- Set up public download page

## Related Documentation

- [TESTING_STRATEGY.md](TESTING_STRATEGY.md) - Detailed testing philosophy
- [SOLUTION_SUMMARY.md](SOLUTION_SUMMARY.md) - Original solution design
- [QUICK_REFERENCE.md](QUICK_REFERENCE.md) - Quick command reference
- [../testing/README.md](../testing/README.md) - Test suite documentation
