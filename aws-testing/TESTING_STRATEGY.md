# NubiferOS Testing Strategy

## Overview

This document explains the recommended testing approach for NubiferOS.

## The Problem with AWS ISO Import

**AWS VM Import/Export does NOT support ISO files.**

Attempting to import an ISO to AWS:
- ❌ Fails with "deleted" status
- ❌ Takes 30-60 minutes before failing
- ❌ Costs money
- ❌ Doesn't test the actual ISO (requires conversion)

## Recommended Testing Strategy

### Phase 1: Local ISO Testing (REQUIRED) ⭐

**Goal:** Verify the ISO works correctly

**Method:** Test locally with QEMU or VirtualBox

**Time:** 2-10 minutes

**Cost:** Free

**What it tests:**
- ✅ ISO boots correctly
- ✅ GRUB bootloader works
- ✅ Live system loads
- ✅ Desktop environment starts
- ✅ Installation process works
- ✅ Installed system boots

**How to run:**
```bash
# Automated tests
cd testing
pytest test-iso-pytest.py -v

# Manual boot test
./test-iso-locally.sh
```

**See:** `testing/README.md` for complete guide

### Phase 2: AWS Testing (OPTIONAL)

**Goal:** Test NubiferOS in AWS environment

**Important:** This does NOT test the ISO. It tests a system built from scratch.

**Method:** Use Packer to build AMI

**Time:** 15-25 minutes

**Cost:** ~$0.10 per build

**What it tests:**
- ✅ NubiferOS components work in AWS
- ✅ Cloud-init integration
- ✅ AWS-specific features
- ❌ Does NOT test the ISO itself

**How to run:**
```bash
cd aws-testing/packer
packer build nubiferos-simple.pkr.hcl
```

**See:** `aws-testing/packer/README.md` for complete guide

## Decision Tree

```
Build ISO
  ↓
Test locally (REQUIRED)
  ↓
Does ISO boot? ──No──→ Fix build, rebuild
  ↓ Yes
Does installation work? ──No──→ Fix installer, rebuild
  ↓ Yes
Does installed system boot? ──No──→ Fix system, rebuild
  ↓ Yes
✅ ISO is good!
  ↓
Need AWS testing? ──No──→ Done! Ship the ISO
  ↓ Yes
Use Packer to build AMI
  ↓
Test AMI in AWS
  ↓
✅ Done!
```

## Why This Strategy?

### Local Testing First

**Pros:**
- ✅ **Fast** - 2-10 minutes vs 30-60 minutes
- ✅ **Free** - No AWS costs
- ✅ **Tests actual ISO** - Not a converted format
- ✅ **Easy to debug** - Direct VM access
- ✅ **Repeatable** - Run as many times as needed
- ✅ **CI/CD friendly** - Can run in GitHub Actions

**Cons:**
- ⚠️ Doesn't test AWS-specific features

### AWS Testing Second (If Needed)

**When to use:**
- You need to test AWS-specific features
- You want to deploy to AWS
- You need to test cloud-init integration
- You want to test in AWS environment

**When NOT to use:**
- Just testing if ISO boots (use local testing)
- Testing installation process (use local testing)
- Testing desktop environment (use local testing)
- CI/CD pipeline (use local testing)

## Comparison

| Aspect | Local Testing | AWS Import | AWS Packer |
|--------|---------------|------------|------------|
| **Tests ISO** | ✅ Yes | ❌ No (fails) | ❌ No |
| **Time** | 2-10 min | 30-60 min (fails) | 15-25 min |
| **Cost** | Free | $2-3 (fails) | $0.10 |
| **Debugging** | Easy | Hard | Medium |
| **CI/CD** | ✅ Yes | ❌ No | ⚠️ Slow |
| **AWS Features** | ❌ No | N/A | ✅ Yes |

## Recommended Workflow

### For Development

```bash
# 1. Build ISO
sudo ./build-nubiferos.sh

# 2. Quick automated test
cd testing
pytest test-iso-pytest.py -v

# 3. If tests pass, manual boot test
./test-iso-locally.sh

# 4. If everything works, commit and push
git add .
git commit -m "Build working ISO"
git push
```

**Time:** 40-50 minutes (35-40 min build + 5-10 min test)

### For CI/CD

```yaml
# .github/workflows/build.yml
jobs:
  build-and-test:
    runs-on: ubuntu-latest
    steps:
      - name: Build ISO
        run: sudo ./build-nubiferos.sh
        
      - name: Test ISO
        run: |
          sudo apt-get install -y qemu-system-x86
          pip install pytest
          cd testing
          pytest test-iso-pytest.py -v
          
      - name: Upload ISO
        if: success()
        uses: actions/upload-artifact@v3
        with:
          name: nubiferos-iso
          path: output/*.iso
```

**Time:** 40-45 minutes per build

### For AWS Deployment (Optional)

```bash
# 1. Build and test ISO locally first
sudo ./build-nubiferos.sh
cd testing && pytest test-iso-pytest.py -v

# 2. If local tests pass, build AMI with Packer
cd aws-testing/packer
packer build nubiferos-simple.pkr.hcl

# 3. Test AMI
aws ec2 run-instances --image-id ami-xxxxx ...
```

**Time:** 55-75 minutes (40 min build + 5 min test + 15-25 min Packer)

## Cost Analysis

### Local Testing Only (Recommended)

- **Build time:** 35-40 minutes (free)
- **Test time:** 5-10 minutes (free)
- **Total cost:** $0
- **Total time:** 40-50 minutes

### With AWS Testing

- **Build time:** 35-40 minutes (free)
- **Local test:** 5-10 minutes (free)
- **Packer build:** 15-25 minutes ($0.10)
- **AWS testing:** 10-30 minutes ($0.20-0.50)
- **Total cost:** $0.30-0.60
- **Total time:** 65-105 minutes

**Savings with local-only:** $0.30-0.60 per build, 25-55 minutes per build

## FAQ

**Q: Do I need to test in AWS?**  
A: No, unless you specifically need AWS-specific features. Local testing is sufficient for verifying the ISO works.

**Q: Why can't we import the ISO to AWS?**  
A: AWS VM Import doesn't support ISO files. It requires disk images (raw, VMDK, VHD).

**Q: What about converting ISO to disk image?**  
A: That requires actually installing the OS, which is what Packer does. But at that point, you're not testing the ISO anymore.

**Q: How do I test AWS-specific features?**  
A: Use Packer to build an AMI, then test that AMI. But understand this tests the components, not the ISO.

**Q: Can I test the ISO in AWS at all?**  
A: Not directly. You'd need to:
  1. Launch an EC2 instance
  2. Attach ISO as virtual CD
  3. Boot from ISO
  4. This is complex and not supported by AWS automation

**Q: What's the fastest way to verify my build?**  
A: Local automated tests: `pytest test-iso-pytest.py -v` (2-3 minutes)

**Q: What if I only care about AWS deployment?**  
A: Skip ISO building entirely. Use Packer to build AMI directly from Debian base + your scripts.

## Conclusion

**For most use cases:**
1. ✅ Build ISO
2. ✅ Test locally
3. ✅ Ship ISO
4. ❌ Skip AWS testing

**Only if you need AWS:**
1. ✅ Build ISO
2. ✅ Test locally
3. ✅ Use Packer to build AMI
4. ✅ Test AMI in AWS

**Never:**
- ❌ Try to import ISO to AWS (doesn't work)
- ❌ Skip local testing (wastes time)
- ❌ Test in AWS without local testing first (expensive)

---

**Bottom Line:** Test locally first. It's faster, free, and actually tests your ISO. Only use AWS if you specifically need AWS features.
