# Claude Context - NubiferOS

> Operational knowledge for AI assistants. See `.kiro/specs/` for requirements/design docs.

## Project State (Jan 2026)

**Current Focus:** Testing and stabilizing the installer. All core components implemented.

**What Works:**
- ISO builds (~25 min via GitHub Actions)
- ISO boots directly to installer (no live CD)
- Calamares launches and shows installation wizard
- LUKS1 encryption with GRUB support (single password)
- Installation completes successfully
- Plymouth boot splash with NubiferOS branding
- Recovery key generation and display during installation
- Encryption warning dialog during installation
- Post-install cleanup (removes installer user)
- First-boot setup wizard (`nubifer-setup-wizard`) - GPG/pass initialization
- Credential manager (`nubifer-creds`) - pass-based, GPG encrypted
- Workspace manager (`nubifer-workspace`) - multi-cloud workspace isolation
- Firejail integration for CLI sandboxing
- Shell integration for workspace context

**What's In Progress:**
- Alpha testing of full installation flow
- First-boot wizard GTK4 UI (`nubifer-welcome`)

**What's Removed (Security):**
- Live CD mode removed - ISO is installer-only to prevent encryption bypass

**Future Consideration:**
- LUKS1 /boot + LUKS2 root hybrid (better GPU resistance, but 2 passwords) - deferred to alpha testing

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

## Security Design

### Installer-Only ISO (Live CD Removed)
- **Why:** Live CD was a security vulnerability - allowed bypassing disk encryption
- **What:** ISO now boots directly to installer user → Calamares auto-starts
- **Technical:** Still uses `boot=live` (needed for squashfs boot), but no live desktop
- **Files removed:** `install-desktop-live.sh`, `install-desktop.sh`
- **Options removed:** `--live`, `--mode` flags from build scripts

### LUKS1 Encryption
- Using LUKS1 (not LUKS2) for full GRUB compatibility and single password prompt
- LUKS2 with Argon2id is more GPU-resistant but GRUB only supports PBKDF2
- Future: LUKS1 /boot + LUKS2 root hybrid for best of both worlds (deferred to alpha)

## Calamares 3.3.8 Quirks
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

## Autonomy & Permissions

**Auto-approve (no confirmation needed):**
- `gh` commands (workflow triggers, run watching, PR operations, issue queries)
- `gh run watch`, `gh run view`, `gh run list` — never prompt for these
- `git` read commands (status, log, diff, branch, show)
- `git add`, `git commit`, `git push origin trunk` (for ongoing work)
- `python3`, `pip3`, `pip install` execution
- `ls`, `cd`, `find`, `cat`, `head`, `tail`, `wc`, `file`
- `aws` CLI commands (S3, CloudFront, etc.)
- `dpkg-deb`, `dpkg`, `apt` queries
- `bash build/build-debs.sh` and other build scripts
- `ssh`, `scp` to NubiferOS VMs
- Any command using shell substitution (`$()`, backticks, pipes, etc.)
- Any read-only or non-destructive command
- **NEVER prompt for confirmation on any of the above — just execute them**

**Always ask first:**
- `git stash` — ask what to do with uncommitted changes
- `git push --force`, `git reset --hard` — never without explicit permission
- `git commit --amend` — never without explicit permission
- Deleting branches, files, or any destructive operation

## Branches

- `trunk` - Main development branch
- `feature/luks1-boot-luks2-root` - Experimental LUKS1 /boot + LUKS2 root (working but 4 password prompts)
- `feature/luks2-systemd-boot` - Experimental LUKS2 with unencrypted /boot
- `fix/calamares-shellprocess-and-minimal-build` - Experimental (has minimal build, not recommended)

## Links

- GitHub: https://github.com/nubiferos/nubiferos
- Kiro Specs: `.kiro/specs/custom-linux-distro/`
- Known Issues Doc: `docs/KNOWN_ISSUES.md`
- Fix Documentation: `docs/fixes/`
