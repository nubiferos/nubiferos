# AWS ISO Import Issue - Root Cause Analysis

## Problem

The CodeBuild pipeline is failing with:
```
Import failed with status deleted
```

## Root Cause

**AWS VM Import/Export does NOT support ISO files directly.**

The current buildspec tries to import an ISO file as a raw disk:
```yaml
aws ec2 import-image \
  --disk-containers "Format=raw,UserBucket={S3Bucket=$ISO_BUCKET,S3Key=$ISO_KEY}"
```

But an **ISO is not a raw disk image**:
- **ISO**: Optical disc image format (ISO 9660 filesystem)
- **Raw disk**: Block device image with partition table, bootloader, and filesystem

AWS VM Import expects:
- Raw disk images (.raw, .img)
- VMDK (VMware)
- VHD/VHDX (Hyper-V)
- OVA (Open Virtualization Format)

## Why It Fails

1. AWS receives the ISO file
2. Tries to interpret it as a raw disk
3. Finds no valid partition table or bootloader
4. Marks import as "deleted" (failed validation)

## Solutions

### Option 1: Build Raw Disk Image Instead of ISO ⭐ RECOMMENDED

Modify the build process to create a raw disk image that can be directly imported.

**Pros:**
- Direct import to AWS
- No conversion needed
- Fastest pipeline

**Cons:**
- Need to modify build system
- Different artifact format

**Implementation:**
```bash
# In build-iso.sh, add option to create raw disk
qemu-img create -f raw nubiferos-disk.raw 20G
# Install system to disk image
# Export as raw disk
```

### Option 2: Use Packer for Automated Installation ⭐ RECOMMENDED

Use HashiCorp Packer to automate the installation process and create an AMI.

**Pros:**
- Industry standard tool
- Automated installation
- Creates AMI directly
- Supports multiple cloud providers

**Cons:**
- Requires Packer configuration
- Longer build time (full installation)

**Implementation:**
See `packer-solution.md` for details.

### Option 3: Convert ISO to Disk in CodeBuild

Convert the ISO to a bootable disk image in the CodeBuild phase.

**Pros:**
- Keep existing ISO build
- Conversion happens in pipeline

**Cons:**
- Complex conversion process
- Requires actual OS installation
- Very slow (30-60 minutes just for conversion)
- Unreliable in automated environment

**Not Recommended** - Too complex and slow.

### Option 4: Use EC2 Image Builder

Use AWS EC2 Image Builder to install from ISO.

**Pros:**
- AWS-native solution
- Handles installation automatically

**Cons:**
- More complex setup
- Additional AWS service
- Higher cost

### Option 5: Manual Process

Manually install in VM, export disk, upload to S3.

**Pros:**
- Simple to understand

**Cons:**
- Not automated
- Defeats purpose of CI/CD

**Not Recommended** - Manual process.

## Recommended Solution: Packer

Use Packer to automate the installation and AMI creation.

### Why Packer?

1. **Industry Standard**: Used by thousands of companies
2. **Multi-Cloud**: Works with AWS, Azure, GCP, etc.
3. **Automated**: Fully automated installation
4. **Reproducible**: Same result every time
5. **Well-Documented**: Extensive documentation and examples

### How It Works

```
ISO File
  ↓
Packer starts EC2 instance
  ↓
Mounts ISO as virtual CD
  ↓
Boots from ISO
  ↓
Automated installation (preseed/kickstart)
  ↓
Packer creates AMI
  ↓
AMI ready for testing
```

### Implementation Steps

1. Create Packer template (`nubiferos.pkr.hcl`)
2. Create preseed file for automated installation
3. Update CodeBuild to use Packer
4. Test and deploy

See `PACKER_IMPLEMENTATION.md` for complete guide.

## Quick Fix for Testing

If you need to test immediately:

1. **Manual AMI Creation:**
   ```bash
   # Launch EC2 instance
   # Attach ISO as CD
   # Install manually
   # Create AMI from instance
   # Use AMI ID in pipeline
   ```

2. **Use Existing Debian AMI:**
   ```bash
   # Start with Debian 12 AMI
   # Run post-install scripts
   # Test NubiferOS components
   ```

## Timeline

- **Packer Implementation**: 1-2 days
- **Raw Disk Build**: 2-3 days
- **Manual Workaround**: 1 hour (but not automated)

## Next Steps

1. ✅ Document the issue (this file)
2. ⬜ Choose solution (recommend Packer)
3. ⬜ Implement solution
4. ⬜ Test pipeline
5. ⬜ Update documentation

## References

- [AWS VM Import/Export Requirements](https://docs.aws.amazon.com/vm-import/latest/userguide/vmie_prereqs.html)
- [Packer AWS Builder](https://www.packer.io/docs/builders/amazon)
- [EC2 Image Builder](https://docs.aws.amazon.com/imagebuilder/)

## Questions?

This is a common issue when trying to import ISOs to AWS. The solution is well-established: use Packer or build raw disk images.

---

**Status**: Issue Identified  
**Priority**: High  
**Recommended Solution**: Implement Packer  
**ETA**: 1-2 days
