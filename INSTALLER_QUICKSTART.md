# NubiferOS Installer Quick Start

## Get the Installer Working in 3 Steps

### Step 1: Generate Calamares Configuration

```bash
cd build
chmod +x setup-calamares-minimal.sh install-calamares.sh
./setup-calamares-minimal.sh
```

This creates all the necessary Calamares configuration files.

### Step 2: Build the ISO

```bash
cd ..
sudo ./build-nubiferos.sh
```

This will:
- Build the base system
- Install Calamares
- Configure auto-boot to installer
- Create the ISO

**Build time**: ~30-40 minutes

### Step 3: Test in QEMU

```bash
qemu-system-x86_64 \
  -cdrom output/NubiferOS-*.iso \
  -m 4096 \
  -enable-kvm \
  -boot d \
  -drive file=test-disk.qcow2,format=qcow2
```

**First time**: Create a test disk:
```bash
qemu-img create -f qcow2 test-disk.qcow2 20G
```

## What You'll See

1. **GRUB Menu** (10 seconds) - Auto-boots to installer
2. **Calamares Welcome** - Click "Next"
3. **Language Selection** - Choose language
4. **Keyboard Layout** - Choose keyboard
5. **Disk Partitioning** - Select disk and encryption
6. **User Creation** - Create your user
7. **Summary** - Review and install
8. **Installation** - Progress bar (~10-15 min)
9. **Finished** - Reboot

## Current Status

✅ **Working**:
- Basic Calamares installer
- GNOME desktop installation
- User creation
- Disk partitioning
- Bootloader installation

⏳ **Not Yet Implemented**:
- Package selection (cloud providers, tools, IDEs)
- Auto-boot to installer (still boots to live environment)
- Minimal ISO (still includes all packages)

## Next Steps

### Make ISO Boot to Installer

Currently the ISO boots to a live environment. To boot directly to Calamares:

1. Remove live-boot packages
2. Configure auto-login
3. Create systemd service to launch Calamares
4. Update GRUB to skip live boot

See `.kiro/specs/iso-auto-boot-fix/tasks.md` for details.

### Add Package Selection

To add the package selection system:

1. Create custom Calamares module
2. Add package definition YAMLs
3. Configure package installation

See `.kiro/specs/installer-package-selection/design.md` for details.

## Troubleshooting

### Calamares doesn't start

Check if Calamares is installed:
```bash
# Mount the ISO
sudo mount -o loop output/NubiferOS-*.iso /mnt
sudo chroot /mnt
which calamares
```

### Build fails at Calamares step

Check the log:
```bash
tail -100 logs/build-*.log | grep -i calamares
```

### ISO boots to desktop instead of installer

This is expected for now. The ISO currently boots to a live GNOME desktop.
To launch Calamares manually:
```bash
sudo calamares
```

### Installation fails

Check Calamares logs:
```bash
# During installation
tail -f /var/log/Calamares.log

# After installation
cat /var/log/Calamares.log
```

## Configuration Files

All Calamares configuration is in:
```
installer/calamares/
├── settings.conf           # Main config
├── modules/                # Module configs
│   ├── welcome.conf
│   ├── partition.conf
│   ├── users.conf
│   ├── packages.conf
│   └── ...
└── branding/nubiferos/     # Branding
    ├── branding.desc
    ├── show.qml
    └── logo.png
```

## Customization

### Change Branding

Edit `installer/calamares/branding/nubiferos/branding.desc`

### Change Default Packages

Edit `installer/calamares/modules/packages.conf`

### Change Partition Defaults

Edit `installer/calamares/modules/partition.conf`

### Change User Defaults

Edit `installer/calamares/modules/users.conf`

## Testing Checklist

- [ ] ISO builds successfully
- [ ] ISO boots in QEMU
- [ ] Calamares launches (manually for now)
- [ ] Can select language
- [ ] Can select keyboard
- [ ] Can partition disk
- [ ] Can create user
- [ ] Installation completes
- [ ] System reboots
- [ ] Can login to installed system
- [ ] GNOME desktop works
- [ ] Network works
- [ ] Can install packages

## Resources

- [Calamares Documentation](https://calamares.io/docs/)
- [Calamares GitHub](https://github.com/calamares/calamares)
- [Module Configuration](https://github.com/calamares/calamares/tree/calamares/src/modules)
- [Branding Guide](https://github.com/calamares/calamares/blob/calamares/src/branding/README.md)

## Getting Help

- Check logs in `logs/build-*.log`
- Check Calamares logs in `/var/log/Calamares.log`
- Review configuration in `installer/calamares/`
- Check the specs in `.kiro/specs/`

---

**Status**: Basic installer configuration complete, ready for testing!
