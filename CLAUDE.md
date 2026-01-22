# Claude Context - NubiferOS

> Operational knowledge for AI assistants. See `.kiro/specs/` for requirements/design docs.

## Project State (Jan 2026)

**Current Focus:** Getting Calamares installer to successfully install to disk with GRUB bootloader.

**What Works:**
- ISO builds (~25 min via GitHub Actions)
- ISO boots to GNOME desktop
- Calamares launches and shows installation wizard
- LUKS encryption setup

**What's Broken/In Progress:**
- Bootloader installation (GRUB) fails during Calamares install
- Shellprocess modules were silently failing (FIXED - see below)

## Critical Bug Fixes Applied

### 1. Calamares shellprocess `args` key (Jan 2026)

**Problem:** Shellprocess configs used invalid `args` key - Calamares silently ignored it.

```yaml
# BROKEN - args is not a valid Calamares key
script:
    - command: "/bin/bash"
      args: ["-c", "..."]  # IGNORED!
```

**Fix:** Moved scripts to external files, call directly:
```yaml
# CORRECT
script:
    - command: "/usr/local/bin/calamares-fix-dev-mounts.sh"
      timeout: 30
```

**Files changed:**
- `scripts/calamares-*.sh` (4 new scripts)
- `installer/calamares/modules/*.conf` (5 configs updated)
- `build/install-calamares.sh` (copies scripts to /usr/local/bin)

### 2. Mount module bind mount issue

**Problem:** Calamares mount module parses `--bind` incorrectly (splits on dashes).

**Workaround:** `fix-dev-mounts.conf` runs AFTER unpackfs to manually bind mount `/dev`.

## Key Architecture

### Build Pipeline
```
build-nubiferos.sh          # Entry point (wrapper)
  └── build/build-iso.sh    # Main build orchestration
        ├── download-debian.sh
        ├── extract-debian.sh
        ├── install-desktop-installer.sh  # Creates 'installer' user, installs GNOME
        ├── install-calamares.sh          # Installs Calamares + helper scripts
        ├── configure-installer-autostart.sh
        └── create_bootable_iso()
```

### Calamares Execution Sequence
```
settings.conf defines:
1. shellprocess@prepare-devices   # udev trigger (dontChroot: true)
2. partition                      # LUKS + partitioning
3. mount                          # Mount target partitions
4. unpackfs                       # Extract squashfs to target
5. shellprocess@fix-dev-mounts    # Bind mount /dev (dontChroot: true) <-- CRITICAL
6. shellprocess@debug-devices     # Verify /dev visible in chroot
7. [system config modules...]
8. shellprocess@prepare-bootloader
9. bootloader                     # GRUB installation <-- CURRENTLY FAILING
10. umount
```

### Key Files

| File | Purpose |
|------|---------|
| `installer/calamares/settings.conf` | Installation sequence |
| `installer/calamares/modules/bootloader.conf` | GRUB configuration |
| `installer/calamares/modules/fix-dev-mounts.conf` | Bind mount workaround |
| `installer/calamares/modules/partition.conf` | LUKS + partition setup |
| `scripts/calamares-*.sh` | External shellprocess scripts |
| `scripts/grub-install-luks-wrapper.sh` | LUKS-aware GRUB wrapper |
| `build/build-iso.sh` | Main build script |
| `.github/workflows/build-iso.yml` | CI/CD pipeline |

## Known Issues

### GRUB Installation in Live Environment
- **Root cause:** Live CD overlay filesystem prevents `grub-install` canonical path resolution
- **Error:** `grub-install: error: failed to get canonical path of '/boot/efi'`
- **Status:** Investigating - shellprocess scripts should help with /dev visibility
- **Docs:** `docs/fixes/BOOTLOADER_OVERLAY_ISSUE_CRITICAL.md`

### Calamares 3.3.8 Quirks
- Installed from bookworm-backports
- Shell is always invoked (no need for `/bin/bash -c`)
- Valid script entry keys: `command`, `timeout`, `verbose`, `environment`
- **NOT valid:** `args` (silently ignored)

## Testing

### Quick Test Cycle
1. Push to `trunk` triggers GitHub Actions build
2. Download ISO from S3 (link in Actions summary)
3. Test in VirtualBox/QEMU with 20GB+ virtual disk
4. Check Calamares logs: `/var/log/installer/` or console output

### Calamares Debug Mode
```bash
sudo calamares -d  # Shows debug output
```

## Branches

- `trunk` - Main development branch
- `fix/calamares-shellprocess-and-minimal-build` - Experimental (has minimal build, not recommended)

## Links

- GitHub: https://github.com/jessetop/nubiferOS
- Kiro Specs: `.kiro/specs/custom-linux-distro/`
- Known Issues Doc: `docs/KNOWN_ISSUES.md`
- Fix Documentation: `docs/fixes/`
