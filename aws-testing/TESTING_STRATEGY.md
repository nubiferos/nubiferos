# NubiferOS Testing Strategy

## Overview

This document outlines the testing strategy for NubiferOS ISO builds across different environments.

## Testing Philosophy

**The boot test is the ultimate validation.** If an ISO boots successfully, it means:
- The bootloader (GRUB) is configured correctly
- The kernel and initrd are present and valid
- The filesystem structure is correct
- All boot dependencies are satisfied

Therefore, content inspection tests (checking for GRUB files, kernel files, etc.) are **redundant if the boot test passes**.

## Testing Environments

### 1. GitHub Actions (Build-Time Testing) ⭐ PRIMARY

**Purpose**: Build and validate the ISO, upload to S3 only if tests pass

**Capabilities**:
- ✅ Full KVM support (fast QEMU)
- ✅ Can mount filesystems
- ✅ Full sudo access
- ✅ Longer timeout limits
- ✅ Integrated with S3 upload

**Current Implementation**: `.github/workflows/build-iso.yml`

**What It Does**:
1. Builds the ISO from scratch
2. Runs basic validation (format, size)
3. Runs boot test with QEMU (KVM-accelerated)
4. Uploads to S3 in two locations:
   - `s3://nubiferos-iso/VERSION/nubiferos-VERSION-TIMESTAMP-COMMIT.iso` (permanent)
   - `s3://nubiferos-iso/nubiferos-latest.iso` (always points to newest)
5. Triggers CodeBuild for AMI creation (on release tags)

**Benefits**:
- ✅ Catches build issues immediately
- ✅ Fast boot testing with KVM
- ✅ Only uploads validated ISOs to S3
- ✅ Automatic versioning and "latest" symlink
- ✅ Triggers downstream AMI creation

### 2. AWS CodeBuild (Post-Upload Validation & AMI Creation)

**Purpose**: Validate ISO from S3 and create AWS AMI for deployment

**Limitations**:
- ❌ No KVM support (QEMU is very slow)
- ❌ Cannot mount filesystems (security restrictions)
- ❌ Limited sudo access
- ⏱️ Shorter timeout limits

**Current Implementation**: 
- `aws-testing/codebuild/test-iso-buildspec.yml` (validation)
- `aws-testing/codebuild/import-iso-buildspec-packer.yml` (AMI creation)

**What It Does**:
1. Downloads ISO from S3 (latest or specific version)
2. Runs basic validation (format, size)
3. Runs boot test using kernel extraction (no KVM needed)
4. (Optional) Creates AWS AMI using Packer
5. (Optional) Publishes AMI for deployment

**Benefits**:
- ✅ Validates S3 upload succeeded
- ✅ Confirms ISO wasn't corrupted during transfer
- ✅ Creates deployable AMI for AWS
- ✅ Triggered automatically on release tags

### 3. Local Development Testing

**Purpose**: Test ISOs during development

**Recommended Approach**:
```bash
# Quick validation
pytest testing/test-iso-pytest.py::TestISOBasics -v

# Full boot test (if KVM available)
pytest testing/test-iso-pytest.py::TestISOBoot -v

# Or manual QEMU test
qemu-system-x86_64 -cdrom output/NubiferOS-*.iso -m 4096 -enable-kvm
```

## Test Categories

### Essential Tests (Always Run)

1. **ISO Format Validation**
   - Verifies ISO 9660 signature
   - Checks file is not corrupted
   - Fast, no dependencies

2. **ISO Size Validation**
   - Ensures ISO is reasonable size (1-10GB)
   - Catches build failures that produce tiny/huge ISOs
   - Fast, no dependencies

3. **Boot Test**
   - **THE MOST IMPORTANT TEST**
   - Validates entire ISO structure
   - Confirms bootloader, kernel, and filesystem work
   - Requires QEMU (KVM preferred)

### Optional Tests (Nice to Have)

4. **Content Inspection**
   - Checks for GRUB files, kernel, squashfs
   - **Redundant if boot test passes**
   - Useful for quick validation without booting
   - Requires `isoinfo` or mount capability

5. **Metadata Validation**
   - Checks ISO volume label
   - Verifies branding
   - Requires `isoinfo`

## Current CI/CD Pipeline

```
┌─────────────────────────────────────────────────────────────┐
│ GitHub Actions (Build & Test)                               │
│ .github/workflows/build-iso.yml                             │
├─────────────────────────────────────────────────────────────┤
│ 1. Build ISO from source                                     │
│ 2. Basic validation (format, size) ✅                       │
│ 3. Boot test with KVM ⭐ CRITICAL ✅                        │
│ 4. Upload to S3 (only if tests pass)                        │
│    - Versioned: s3://bucket/VERSION/iso                     │
│    - Latest: s3://bucket/nubiferos-latest.iso               │
│ 5. Trigger CodeBuild (on release tags)                      │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ AWS CodeBuild (Validation & AMI Creation)                   │
│ aws-testing/codebuild/*.yml                                 │
├─────────────────────────────────────────────────────────────┤
│ 1. Download ISO from S3                                      │
│ 2. Basic validation (format, size) ✅                       │
│ 3. Quick boot test (kernel extraction) ✅                   │
│ 4. Create AMI with Packer (optional) 🚀                     │
│ 5. Publish AMI for deployment                               │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ Distribution                                                 │
├─────────────────────────────────────────────────────────────┤
│ - ISO: Download from S3 (latest or versioned)               │
│ - AMI: Deploy in AWS from AMI catalog                       │
│ - Users: Install from ISO or launch from AMI                │
└─────────────────────────────────────────────────────────────┘
```

### Workflow Triggers

- **Push to main/develop**: Build, test, upload to S3
- **Pull Request**: Build and test (no upload)
- **Release Tag (v*)**: Build, test, upload, **create AMI**
- **Manual**: Can trigger any workflow manually

## Why This Strategy?

### Avoid Redundant Testing
- Content inspection tests are redundant if boot test passes
- If ISO boots, the structure must be correct
- Focus on the definitive test (boot) rather than proxy tests (content)

### Environment-Appropriate Testing
- Use GitHub Actions for heavy testing (has KVM)
- Use CodeBuild for light validation (no KVM)
- Don't try to do full testing in restricted environments

### Fast Feedback
- Basic tests run in seconds
- Boot test runs in 1-2 minutes (with KVM)
- Content inspection adds time without adding value

### Reliability
- Boot test is the most reliable indicator of ISO quality
- Content inspection can have false positives/negatives
- If it boots, it works

## Future Enhancements

### Phase 2: Installer Testing
Once we implement the installer-only ISO (from the spec):
- Boot to Calamares installer
- Test unattended installation
- Verify installed system boots

### Phase 3: Integration Testing
- Test full installation workflow
- Verify post-install scripts
- Test cloud-init integration
- Validate security hardening

## Conclusion

**Keep it simple**: 
1. Build the ISO
2. Check it's valid (format, size)
3. Boot it (the ultimate test)
4. If it boots, ship it

Everything else is optional and potentially redundant.
