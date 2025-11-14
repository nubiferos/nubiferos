# NubiferOS ISO Build Checklist

## Pre-Build Checklist

### System Requirements
- [ ] Debian 12 or Ubuntu 22.04+ host system
- [ ] 50GB+ free disk space
- [ ] 8GB+ RAM (16GB recommended)
- [ ] Root/sudo access
- [ ] Internet connection

### Dependencies
```bash
sudo apt-get install -y \
  debootstrap \
  squashfs-tools \
  xorriso \
  grub-pc-bin \
  grub-efi-amd64-bin \
  mtools \
  dosfstools \
  isolinux \
  syslinux-utils
```

### Build Steps

1. **Generate Branding Images** (optional)
```bash
cd brand
./generate-images.sh
cd ..
```

2. **Build ISO**
```bash
sudo ./build/build-iso.sh
```

3. **Find ISO**
```bash
ls -lh output/nubiferos-*.iso
```

4. **Test in VirtualBox**
```bash
# Create VM with:
# - Type: Linux
# - Version: Debian (64-bit)
# - RAM: 4GB minimum
# - Disk: 20GB minimum
# - Mount ISO as optical drive
```

## Build Time Estimates

- Download Debian base: 5-10 minutes
- Extract and customize: 10-15 minutes
- Install packages: 15-20 minutes
- Create ISO: 5-10 minutes
- **Total: 35-55 minutes**

## Expected Output

```
output/
├── nubiferos-1.0-amd64.iso          # Bootable ISO (~2-3GB)
└── nubiferos-1.0-amd64.iso.sha256   # Checksum
```

## Quick Test Commands

```bash
# Check ISO size
ls -lh output/nubiferos-1.0-amd64.iso

# Verify checksum
cd output && sha256sum -c nubiferos-1.0-amd64.iso.sha256

# Test boot in QEMU (if available)
qemu-system-x86_64 \
  -cdrom output/nubiferos-1.0-amd64.iso \
  -m 4096 \
  -enable-kvm \
  -boot d
```

## What's Included

✅ Debian 12 base system
✅ GNOME desktop with Wayland
✅ Cloud tools (AWS, Azure, GCP, Oracle CLIs)
✅ Workspace manager with GNOME integration
✅ Credential manager (pass/GPG)
✅ Firejail security isolation
✅ Security hardening (AppArmor, firewall, etc.)
✅ Browser configuration
✅ IDE plugin installer
✅ Update checker
✅ Setup wizard
✅ Branding and wallpapers

## Troubleshooting

### Build fails with "Permission denied"
```bash
# Make sure running with sudo
sudo ./build/build-iso.sh
```

### Build fails with "No space left"
```bash
# Check disk space
df -h

# Clean up if needed
sudo rm -rf work/
```

### Build fails downloading packages
```bash
# Check internet connection
ping debian.org

# Try again (downloads are cached)
sudo ./build/build-iso.sh
```

## After Build

1. **Test in VM first** - Don't install on real hardware yet
2. **Verify GNOME loads** - Check desktop environment works
3. **Test workspace manager** - Create and switch workspaces
4. **Test GNOME integration** - Watch desktops switch
5. **Report issues** - Note any problems for fixes

## VirtualBox Setup

```bash
# Create VM
VBoxManage createvm --name "NubiferOS-Test" --ostype Debian_64 --register

# Configure VM
VBoxManage modifyvm "NubiferOS-Test" \
  --memory 4096 \
  --vram 128 \
  --cpus 2 \
  --audio none \
  --graphicscontroller vmsvga \
  --boot1 dvd

# Create disk
VBoxManage createhd --filename ~/VirtualBox\ VMs/NubiferOS-Test/disk.vdi --size 20480

# Attach disk
VBoxManage storagectl "NubiferOS-Test" --name "SATA" --add sata
VBoxManage storageattach "NubiferOS-Test" --storagectl "SATA" --port 0 --device 0 --type hdd --medium ~/VirtualBox\ VMs/NubiferOS-Test/disk.vdi

# Attach ISO
VBoxManage storagectl "NubiferOS-Test" --name "IDE" --add ide
VBoxManage storageattach "NubiferOS-Test" --storagectl "IDE" --port 0 --device 0 --type dvddrive --medium output/nubiferos-1.0-amd64.iso

# Start VM
VBoxManage startvm "NubiferOS-Test"
```

## Next Steps After Testing

1. Document any issues found
2. Fix critical bugs
3. Rebuild ISO with fixes
4. Test again
5. Iterate until stable
6. Set up GitHub Actions for automated builds
