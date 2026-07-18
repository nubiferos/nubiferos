# NubiferOS ISO Testing

Fast local testing of the ISO before AWS deployment.

## Automated Boot Test (CI and local)

`test-iso-boot.sh` boots the ISO headless in QEMU and verifies it reaches a
running Calamares installer — no display or interaction needed. It runs
automatically in CI (Test ISO workflow) after every build.

```bash
./testing/test-iso-boot.sh path/to/nubiferos.iso [artifacts-dir]
```

How it verifies: ISOs built with the `nubifer-boot-test.service` marker
(`BOOT-TEST.txt` present in the ISO root) emit progress markers over the
serial console — `service-started`, `graphical-target`, `calamares-running` —
which the harness asserts. Older ISOs fall back to a weaker screenshot-only
check (display alive and non-blank). Artifacts (serial log + periodic PPM
screenshots) land in the artifacts dir; in CI they're uploaded as the
`boot-test-artifacts` artifact.

Uses KVM when `/dev/kvm` is available (~2-5 min), TCG emulation otherwise
(slower; timeout raised automatically). The marker service only runs in the
live installer environment (`boot=live` guard) — it is inert on installed
systems and real hardware.

## Why Test Locally First?

Testing the ISO locally is:
- ✅ **Much faster** - 5 minutes vs 30-60 minutes for AWS conversion
- ✅ **Free** - No AWS costs
- ✅ **Easier to debug** - Direct access to VM
- ✅ **Tests the actual ISO** - Not a converted format

**Recommended workflow:**
1. Build ISO
2. Test locally (this directory)
3. If tests pass, deploy to AWS (optional)

## Quick Start

### Option 1: Manual Testing with QEMU (Fastest)

```bash
# Test with QEMU
./testing/test-iso-locally.sh

# Or specify ISO path
./testing/test-iso-locally.sh output/NubiferOS-1.0-amd64.iso qemu
```

**Time:** 5-10 minutes of manual testing

### Option 2: Manual Testing with VirtualBox

```bash
# Test with VirtualBox
./testing/test-iso-locally.sh output/NubiferOS-1.0-amd64.iso virtualbox
```

**Time:** 5-10 minutes of manual testing

### Option 3: Automated Testing with pytest

```bash
# Install dependencies
pip install pytest

# Run automated tests
cd testing
pytest test-iso-pytest.py -v

# Or with specific ISO
ISO_PATH=../output/NubiferOS-1.0-amd64.iso pytest test-iso-pytest.py -v
```

**Time:** 2-3 minutes automated

## What Gets Tested

### Manual Tests (QEMU/VirtualBox)
- ✅ ISO boots
- ✅ GRUB bootloader works
- ✅ Live system loads
- ✅ Desktop environment starts
- ✅ Installation process works
- ✅ Installed system boots

### Automated Tests (pytest)
- ✅ ISO file exists and is valid size
- ✅ ISO format is correct (ISO 9660)
- ✅ ISO boots in QEMU
- ✅ ISO boots with minimum RAM (2GB)
- ✅ Bootloader files present
- ✅ Kernel present
- ✅ Squashfs filesystem present
- ✅ Volume label correct

## Prerequisites

### For QEMU Testing

**Ubuntu/Debian:**
```bash
sudo apt-get install qemu-system-x86 qemu-utils
```

**macOS:**
```bash
brew install qemu
```

**Fedora:**
```bash
sudo dnf install qemu-system-x86
```

### For VirtualBox Testing

Download from: https://www.virtualbox.org/wiki/Downloads

### For Automated Testing

```bash
pip install pytest
sudo apt-get install isoinfo  # For ISO metadata tests
```

## Testing Workflow

### 1. Build ISO

```bash
sudo ./build-nubiferos.sh
```

### 2. Quick Automated Test

```bash
cd testing
pytest test-iso-pytest.py -v
```

**Expected output:**
```
test_iso_pytest.py::TestISOBasics::test_iso_exists PASSED
test_iso_pytest.py::TestISOBasics::test_iso_size PASSED
test_iso_pytest.py::TestISOBasics::test_iso_format PASSED
test_iso_pytest.py::TestISOBoot::test_iso_boots PASSED
...
```

### 3. Manual Boot Test

```bash
./test-iso-locally.sh
```

**What to check:**
- [ ] GRUB menu appears
- [ ] Live system boots
- [ ] GNOME desktop loads
- [ ] Can open terminal
- [ ] Can start installation
- [ ] Installation completes
- [ ] Installed system boots

### 4. If Tests Pass → Deploy to AWS (Optional)

Only after local tests pass:
```bash
# Upload to S3
aws s3 cp output/NubiferOS-1.0-amd64.iso s3://your-bucket/

# Run AWS pipeline (if needed)
```

## CI/CD Integration

### GitHub Actions

Add to `.github/workflows/build.yml`:

```yaml
- name: Test ISO locally
  run: |
    sudo apt-get install -y qemu-system-x86
    pip install pytest
    cd testing
    pytest test-iso-pytest.py -v
    
- name: Manual boot test (optional)
  run: |
    timeout 120 ./testing/test-iso-locally.sh || true
```

### GitLab CI

Add to `.gitlab-ci.yml`:

```yaml
test-iso:
  stage: test
  script:
    - apt-get update && apt-get install -y qemu-system-x86 python3-pytest
    - cd testing
    - pytest test-iso-pytest.py -v
```

## Troubleshooting

### QEMU: "Could not access KVM kernel module"

**Solution:** Run without KVM:
```bash
# Edit test-iso-locally.sh, remove -enable-kvm flag
```

### VirtualBox: "VM failed to start"

**Solution:** Check virtualization is enabled in BIOS

### pytest: "QEMU not installed"

**Solution:** Install QEMU:
```bash
sudo apt-get install qemu-system-x86
```

### ISO doesn't boot

**Possible causes:**
- Bootloader not installed correctly
- Missing kernel files
- Corrupted ISO

**Debug:**
```bash
# Check ISO contents
sudo mount -o loop output/NubiferOS-1.0-amd64.iso /mnt
ls -la /mnt/boot/
sudo umount /mnt

# Check ISO format
isoinfo -d -i output/NubiferOS-1.0-amd64.iso
```

## Performance Comparison

| Method | Time | Cost | Tests Actual ISO |
|--------|------|------|------------------|
| **Local QEMU** | 5 min | Free | ✅ Yes |
| **Local VirtualBox** | 5 min | Free | ✅ Yes |
| **pytest Automated** | 2 min | Free | ✅ Yes |
| **AWS Import** | 30-60 min | $2-3 | ❌ No (converts format) |
| **AWS Packer** | 15-25 min | $0.10 | ❌ No (installs from scratch) |

**Recommendation:** Always test locally first!

## Advanced Testing

### Test Installation Process

```bash
# Start VM with QEMU
qemu-system-x86_64 \
    -cdrom output/NubiferOS-1.0-amd64.iso \
    -boot d \
    -m 4096 \
    -smp 2 \
    -drive file=test-disk.qcow2,format=qcow2 \
    -enable-kvm

# Go through installation
# Then boot from disk to test installed system
qemu-system-x86_64 \
    -drive file=test-disk.qcow2,format=qcow2 \
    -m 4096 \
    -enable-kvm
```

### Test with Different RAM Sizes

```bash
# Test with 2GB (minimum)
qemu-system-x86_64 -cdrom output/NubiferOS-1.0-amd64.iso -m 2048 -enable-kvm

# Test with 8GB (recommended)
qemu-system-x86_64 -cdrom output/NubiferOS-1.0-amd64.iso -m 8192 -enable-kvm
```

### Test Network Connectivity

```bash
# Start VM with network
qemu-system-x86_64 \
    -cdrom output/NubiferOS-1.0-amd64.iso \
    -m 4096 \
    -enable-kvm \
    -net nic -net user

# In VM, test network
ping google.com
curl https://aws.amazon.com
```

## Files

- **`test-iso-locally.sh`** - Manual testing script (QEMU/VirtualBox)
- **`test-iso-pytest.py`** - Automated pytest tests
- **`README.md`** - This file

## Next Steps

1. ✅ Build ISO
2. ✅ Run automated tests (`pytest test-iso-pytest.py`)
3. ✅ Run manual boot test (`./test-iso-locally.sh`)
4. ✅ Verify installation works
5. ⬜ If all tests pass, optionally deploy to AWS

## FAQ

**Q: Do I need to test in AWS?**  
A: No! Local testing is sufficient for most cases. AWS testing is only needed if you specifically want to test AWS-specific features or deploy to AWS.

**Q: How long does local testing take?**  
A: 2-5 minutes automated, 5-10 minutes manual.

**Q: Can I automate the installation test?**  
A: Yes, but it's complex. Consider using preseed/kickstart files for automated installation testing.

**Q: What if local tests pass but AWS fails?**  
A: AWS doesn't support ISO import anyway. If you need AWS, use Packer (which installs from scratch, not from ISO).

---

**Recommendation:** Test locally first. It's faster, free, and tests the actual ISO you built.
