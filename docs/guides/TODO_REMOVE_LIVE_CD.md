# TODO: Remove Live CD Before Alpha Release

## Priority: HIGH - Security Critical

## Issue
Currently, the ISO boots as a **live CD** which is a **major security vulnerability** for the intended use case.

### Security Problem
- Anyone with physical access can boot from the ISO
- Live environment can access the hard drive
- Bypasses full disk encryption if keys are accessible
- Defeats the entire security model of preventing data theft via physical access
- **This is the opposite of what we want for a secure workstation**

## Current State (Testing Only)
- ISO uses `boot=live` parameter
- System boots into RAM from ISO
- Live user with auto-login for testing
- **DO NOT SHIP THIS TO PRODUCTION**

## Required Changes Before Alpha

### 1. Remove Live Boot System
- [ ] Remove `live-boot` and `live-boot-initramfs-tools` packages
- [ ] Remove `boot=live` from GRUB configuration
- [ ] Remove live user creation

### 2. Implement Installer-Only ISO
- [ ] Add Calamares installer or Debian installer
- [ ] Boot directly to installer (no live environment)
- [ ] Installer must enforce:
  - Full disk encryption (LUKS)
  - Secure boot configuration
  - Strong password requirements
  - TPM integration if available

### 3. Post-Installation Security
- [ ] System only boots from encrypted hard drive
- [ ] No way to boot into live environment
- [ ] BIOS/UEFI password protection recommended
- [ ] Secure boot enabled
- [ ] Boot order locked to internal drive only

### 4. Alternative: Separate ISOs
Consider creating two separate ISOs:
- **Testing ISO**: Live CD for development/testing (clearly marked)
- **Production ISO**: Installer-only for deployment

## Files to Modify

### Remove Live Boot:
- `build/install-desktop.sh` - Remove live-boot packages
- `build/build-iso.sh` - Remove `boot=live` from GRUB config
- `build/build-iso.sh` - Remove live user creation

### Add Installer:
- Create `build/install-calamares.sh` or use Debian installer
- Update GRUB to boot to installer
- Configure installer for mandatory encryption

## Testing Checklist
- [ ] Verify ISO boots directly to installer
- [ ] Verify no live environment is accessible
- [ ] Verify full disk encryption is enforced
- [ ] Verify system only boots from encrypted drive after install
- [ ] Verify no bypass methods exist

## Timeline
**Must be completed before Alpha release**

## Related Documentation
- `docs/SECURITY_SUMMARY.md` - Update to reflect installer-only approach
- `DESIGN_DECISIONS.md` - Document why live CD was removed
- `README.md` - Update installation instructions

## Notes
The current live CD is **ONLY for testing and development**. It must be removed before any production use or Alpha release. The live CD fundamentally undermines the security goals of the project.

---

**Status**: 🔴 BLOCKING ISSUE FOR ALPHA
**Assigned**: TBD
**Due**: Before Alpha Release
