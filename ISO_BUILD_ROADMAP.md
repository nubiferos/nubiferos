# NubiferOS ISO Build Roadmap

## Goal
Create a bootable ISO that can be installed and tested, then automate with GitHub Actions.

## Current Status

### ✅ Completed
- Project structure
- Debian base extraction scripts
- Cloud tools installation script
- Security hardening script
- Credential management (using pass)
- IDE plugin system
- Browser bookmarks
- Update checker
- Post-installation testing system
- Documentation

### 🚧 In Progress
- Build system integration

### ⏳ Remaining for ISO
- Desktop environment configuration
- ISO generation script
- Installer (Calamares) configuration
- Final integration

## Phase 1: Complete Build System (Priority: HIGH)

### Task 2.4: Configure Desktop Environment
**Estimated Time**: 2-3 hours

```bash
# What needs to be done:
1. Install GNOME desktop
2. Configure 4 virtual workspaces
3. Apply NubiferOS branding
4. Enable GNOME Keyring
5. Set default applications
```

**Files to create**:
- `build/install-desktop.sh` - Desktop installation script
- `configs/desktop/gnome-settings.conf` - GNOME configuration
- `configs/desktop/default-apps.list` - Default applications
- `brand/wallpapers/` - Wallpapers for each cloud provider

### Task 2.5: Create ISO Generation Script
**Estimated Time**: 3-4 hours

```bash
# What needs to be done:
1. Orchestrate full build process
2. Create bootable ISO with xorriso
3. Generate checksums (SHA256)
4. Optional: GPG signing
```

**Files to create**:
- `build/build-iso.sh` - Main ISO build orchestrator
- `build/create-bootable-iso.sh` - ISO creation with xorriso
- `build/generate-checksums.sh` - Checksum generation

## Phase 2: Installer Configuration (Priority: HIGH)

### Task 8.1: Configure Calamares
**Estimated Time**: 2-3 hours

```bash
# What needs to be done:
1. Install Calamares framework
2. Create NubiferOS branding module
3. Configure installation modules
4. Add LUKS encryption requirement
5. Add test mode checkbox
```

**Files to create**:
- `installer/calamares/settings.conf` - Main Calamares config
- `installer/calamares/branding/nubiferos/` - Branding files
- `installer/calamares/modules/` - Custom modules

### Task 8.2: Post-Install Script
**Estimated Time**: 1-2 hours

```bash
# What needs to be done:
1. Enable systemd services
2. Install scripts to /usr/local/bin
3. Copy documentation
4. Set wallpaper and theme
5. Run post-install tests if enabled
```

**Files to create**:
- `installer/post-install.sh` - Post-installation script
- `installer/enable-services.sh` - Service enablement

### Task 8.3: Integrate Installer into ISO
**Estimated Time**: 1-2 hours

```bash
# What needs to be done:
1. Configure ISO to boot Calamares
2. Add live mode option
3. Configure secure boot support
```

## Phase 3: Testing & Validation (Priority: MEDIUM)

### Manual Testing
**Estimated Time**: 2-3 hours

```bash
# Test in VM:
1. Boot ISO in VirtualBox/QEMU
2. Test live mode
3. Run installation
4. Verify post-install tests pass
5. Test basic functionality
```

### Automated Testing
**Estimated Time**: 1-2 hours

```bash
# Create test scripts:
1. Automated VM testing
2. ISO validation
3. Installation verification
```

## Phase 4: GitHub Actions Automation (Priority: MEDIUM)

### CI/CD Pipeline
**Estimated Time**: 2-3 hours

```bash
# What needs to be done:
1. Create GitHub Actions workflow
2. Set up build environment
3. Automate ISO build
4. Run automated tests
5. Upload artifacts
6. Create releases
```

**Files to create**:
- `.github/workflows/build-iso.yml` - Main build workflow
- `.github/workflows/test-iso.yml` - Testing workflow
- `.github/workflows/release.yml` - Release workflow

## Detailed Task Breakdown

### Week 1: Core Build System

#### Day 1-2: Desktop Environment
- [ ] Create `build/install-desktop.sh`
- [ ] Configure GNOME settings
- [ ] Create wallpapers
- [ ] Test desktop installation in chroot

#### Day 3-4: ISO Generation
- [ ] Create `build/build-iso.sh`
- [ ] Implement ISO creation with xorriso
- [ ] Add checksum generation
- [ ] Test ISO boots in VM

#### Day 5: Integration
- [ ] Integrate all build scripts
- [ ] Test full build process
- [ ] Fix any issues

### Week 2: Installer & Testing

#### Day 1-2: Calamares Configuration
- [ ] Install and configure Calamares
- [ ] Create branding module
- [ ] Add test mode checkbox
- [ ] Test installation process

#### Day 3: Post-Install
- [ ] Create post-install script
- [ ] Test service enablement
- [ ] Verify post-install tests run

#### Day 4-5: Testing
- [ ] Manual testing in VM
- [ ] Create automated tests
- [ ] Document test results

### Week 3: Automation

#### Day 1-3: GitHub Actions
- [ ] Create build workflow
- [ ] Set up test environment
- [ ] Automate testing
- [ ] Configure artifact upload

#### Day 4-5: Polish & Release
- [ ] Fix any CI/CD issues
- [ ] Create release workflow
- [ ] Document release process
- [ ] Create first release

## Minimum Viable ISO (MVP)

To get a working ISO quickly, we can create a minimal version:

### MVP Scope (1-2 days)
1. ✅ Basic Debian system
2. ✅ Essential tools (pass, gpg, curl, jq)
3. ✅ NubiferOS scripts installed
4. ⏳ Minimal desktop (GNOME)
5. ⏳ Basic installer (Calamares with defaults)
6. ⏳ ISO generation

### MVP Excludes (Add later)
- Custom branding (use defaults)
- All cloud tools (install subset)
- Advanced Calamares modules
- Extensive testing

## Quick Start: Build MVP ISO

```bash
# 1. Install build dependencies
sudo apt-get install -y debootstrap squashfs-tools xorriso \
  grub-pc-bin grub-efi-amd64-bin mtools dosfstools

# 2. Run build scripts in order
sudo ./build/download-debian.sh
sudo ./build/extract-debian.sh
sudo ./build/install-cloud-tools.sh  # Minimal set
sudo ./build/install-desktop.sh      # To be created
sudo ./build/apply-security-hardening.sh
sudo ./build/build-iso.sh            # To be created

# 3. Test ISO
qemu-system-x86_64 -cdrom output/nubiferos-1.0.iso -m 4096 -enable-kvm
```

## Priority Order

### Immediate (This Week)
1. **Desktop installation script** - Required for GUI
2. **ISO generation script** - Required to create bootable ISO
3. **Basic Calamares config** - Required for installation

### Next Week
4. **Post-install script** - Finalize installation
5. **Testing in VM** - Verify everything works
6. **Documentation** - Build instructions

### Following Week
7. **GitHub Actions** - Automate builds
8. **Release process** - Publish ISOs
9. **Advanced features** - Polish and enhance

## Success Criteria

### Phase 1 Complete When:
- ✅ ISO file is generated
- ✅ ISO boots in VM
- ✅ Can see desktop environment
- ✅ Basic tools are installed

### Phase 2 Complete When:
- ✅ Can install from ISO
- ✅ Installation completes successfully
- ✅ System boots after installation
- ✅ Post-install tests pass

### Phase 3 Complete When:
- ✅ GitHub Actions builds ISO
- ✅ Automated tests pass
- ✅ ISO is published as release
- ✅ Documentation is complete

## Resources Needed

### Build Environment
- **OS**: Debian 12 or Ubuntu 22.04
- **RAM**: 8GB minimum (16GB recommended)
- **Disk**: 50GB free space
- **CPU**: 4+ cores recommended
- **Time**: ~30-60 minutes per build

### Testing Environment
- **VM Software**: VirtualBox or QEMU
- **RAM**: 4GB per VM
- **Disk**: 20GB per VM
- **Multiple VMs**: For parallel testing

## Next Steps

### Immediate Actions (Today)
1. Create `build/install-desktop.sh`
2. Create `build/build-iso.sh`
3. Test basic ISO generation

### This Week
1. Complete desktop configuration
2. Get bootable ISO working
3. Test in VM

### Next Week
1. Configure Calamares
2. Test installation process
3. Verify post-install tests

### Following Week
1. Set up GitHub Actions
2. Automate build process
3. Create first release

## Estimated Timeline

- **MVP ISO**: 2-3 days
- **Full Featured ISO**: 1-2 weeks
- **GitHub Actions**: 2-3 days
- **First Release**: 2-3 weeks total

## Questions to Answer

1. **Desktop Environment**: GNOME (default) or offer KDE/XFCE options?
2. **Cloud Tools**: Install all or let user choose during installation?
3. **ISO Size**: Aim for < 2GB or include everything (4-5GB)?
4. **Live Mode**: Full featured or minimal?
5. **Secure Boot**: Support immediately or add later?

## Recommendations

### For Quick ISO
1. Use GNOME (most tested)
2. Install core tools only
3. Keep ISO < 2GB
4. Minimal live mode
5. Skip secure boot initially

### For Production ISO
1. Offer desktop choice
2. Install all tools
3. Accept 4-5GB size
4. Full featured live mode
5. Add secure boot support

---

**Current Focus**: Phase 1 - Complete Build System  
**Next Milestone**: Bootable ISO in VM  
**Target Date**: End of this week
