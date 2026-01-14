# ISO Size Reduction Changes

## Summary
Reduced ISO size from **~24GB → ~18GB** (estimated **6GB savings**)

## Changes Made

### 1. Removed Heavy IDEs from ISO (Saves ~4.2GB)

**Removed:**
- IntelliJ IDEA Community Edition: 2.4GB
- PyCharm Community Edition: 1.8GB  
- Eclipse: 382MB

**Kept:**
- Kate (lightweight text editor): ~50MB
- VSCode/Codium available via post-install

**Rationale:** Heavy IDEs are better installed post-deployment based on user needs. This significantly reduces ISO size while maintaining functionality through post-install options.

**Files Modified:**
- `build/install-cloud-tools.sh` - Commented out IDE installations

### 2. Moved Grafana to Post-Install (Saves ~697MB)

**Removed:**
- Grafana monitoring tool: 697MB

**Rationale:** Grafana is a specialized monitoring tool not needed by all users. Available as optional post-install component.

**Files Modified:**
- `build/install-cloud-tools.sh` - Commented out Grafana installation

### 3. Minimal Font Installation (Saves ~600MB)

**Changed:**
- `fonts-dejavu` → `fonts-dejavu-core`
- `fonts-liberation` → `fonts-liberation2`
- `fonts-noto` → `fonts-noto-core`
- Kept: `fonts-noto-color-emoji` (essential for modern UI)

**Rationale:** Full font packages include fonts for dozens of languages. Core packages provide essential Latin fonts. Language-specific fonts will be offered during setup wizard.

**Files Modified:**
- `build/install-desktop.sh` - Updated font packages

### 4. Locale Cleanup (Saves ~400MB)

**Removed:**
- All non-English locales and translations
- Kept only: `en`, `en_US`, `en_US.UTF-8`

**Implementation:**
- Installed `localepurge` tool
- Configured to keep only English locales
- Removed `/usr/share/locale/*` except English

**Rationale:** Most users only need one language. Setup wizard will offer to download additional language packs during first-run configuration.

**Files Modified:**
- `build/install-desktop.sh` - Added `cleanup_locales()` function

## What's Still Included

### Cloud Tools (Kept - ~2GB)
- AWS CLI: 708MB
- Azure CLI: 633MB
- Terraform, Pulumi, kubectl, helm, etc: ~1.9GB

**Rationale:** These are core tools for the cloud workstation use case and should be immediately available.

### Documentation (Kept - ~184MB)
- All man pages and documentation kept
- Essential for offline reference

### Essential Components
- GNOME Desktop
- Firefox browser
- Security tools
- Networking tools
- Development libraries

## Post-Install Options

Users can install additional components after deployment:

### IDEs (via `nubifer-install` command):
```bash
nubifer-install ide intellij    # IntelliJ IDEA CE
nubifer-install ide pycharm     # PyCharm CE
nubifer-install ide eclipse     # Eclipse
nubifer-install ide vscode      # VS Code
nubifer-install ide vscodium    # VSCodium
```

### Monitoring Tools:
```bash
nubifer-install monitoring grafana
```

### Language Packs (via setup wizard):
- Chinese (Simplified/Traditional)
- Japanese
- Korean
- Arabic
- Russian
- Spanish
- French
- German
- And more...

### Font Packs (via setup wizard):
- CJK fonts (Chinese, Japanese, Korean)
- Arabic fonts
- Cyrillic fonts
- Indic fonts
- And more...

## Setup Wizard Enhancements Needed

The setup wizard (`scripts/nubifer-setup-wizard`) should be enhanced to:

1. **Language Selection:**
   - Detect system language
   - Offer to download language packs
   - Install appropriate locales
   - Install language-specific fonts

2. **Optional Components:**
   - IDE selection (IntelliJ, PyCharm, Eclipse, etc.)
   - Monitoring tools (Grafana, Prometheus)
   - Additional development tools

3. **Font Selection:**
   - Detect language needs
   - Offer language-specific font packs
   - Install emoji and symbol fonts if needed

## Expected Results

### Before:
- ISO Size: ~24GB
- Squashfs: ~6.7GB compressed
- Chroot: ~24GB uncompressed

### After (Estimated):
- ISO Size: ~18GB (-25%)
- Squashfs: ~5GB compressed (-25%)
- Chroot: ~18GB uncompressed (-25%)

### Build Time:
- Slightly faster due to fewer packages to download and install
- Estimated 5-10 minutes faster build time

## Testing Checklist

- [ ] Verify ISO builds successfully
- [ ] Verify ISO size is reduced
- [ ] Verify system boots correctly
- [ ] Verify Kate text editor works
- [ ] Verify cloud tools still function
- [ ] Verify fonts render correctly for English
- [ ] Verify post-install IDE installation works
- [ ] Test setup wizard language selection
- [ ] Test setup wizard font installation

## Future Optimizations

Additional size reductions possible:
- Remove development headers (~87MB) - install on-demand
- Compress man pages (~50MB savings)
- Remove unused kernel modules (~100MB)
- Strip debug symbols (~200MB)

Total potential additional savings: ~400MB

## Notes

- This is a **breaking change** for users expecting pre-installed IDEs
- Update documentation to reflect post-install process
- Setup wizard must be enhanced before Alpha release
- Consider creating "Developer Edition" ISO with all IDEs for convenience
