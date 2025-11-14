# NubiferOS Branding

This directory contains all branding and identity configuration for NubiferOS.

## Files

- **brand.conf** - Central brand configuration with all variables
- **load-brand.sh** - Helper script to load brand variables in other scripts
- **brandideas.md** - Brand identity concepts, taglines, and visual ideas

## Usage

### In Shell Scripts

Source the brand loader at the beginning of your script:

```bash
#!/bin/bash
source "$(dirname "$0")/../brand/load-brand.sh"

echo "Building ${BRAND_NAME} version ${BRAND_VERSION}"
echo "Tagline: ${BRAND_TAGLINE}"
```

### In Build Scripts

The build configuration (`build/config.sh`) automatically loads brand variables:

```bash
source build/config.sh
echo "Distribution: ${DISTRO_NAME}"  # Uses BRAND_NAME
```

### Available Variables

All variables are prefixed with `BRAND_` for easy identification:

**Core Identity:**
- `BRAND_NAME` - Full name (NubiferOS)
- `BRAND_SHORT_NAME` - Short name (Nubifer)
- `BRAND_CLI_NAME` - CLI command name (nubifer)
- `BRAND_TAGLINE` - Primary tagline
- `BRAND_VERSION` - Current version
- `BRAND_CODENAME` - Release codename

**Web & Contact:**
- `BRAND_DOMAIN`, `BRAND_WEBSITE`, `BRAND_DOCS_URL`, `BRAND_REPO_URL`
- `BRAND_EMAIL`, `BRAND_SUPPORT_EMAIL`
- `BRAND_TWITTER`, `BRAND_DISCORD`

**Legal:**
- `BRAND_COPYRIGHT`, `BRAND_LICENSE`, `BRAND_TRADEMARK`

**Visual:**
- `BRAND_PRIMARY_COLOR`, `BRAND_SECONDARY_COLOR`, `BRAND_ACCENT_COLOR`
- `BRAND_AWS_COLOR`, `BRAND_AZURE_COLOR`, `BRAND_GCP_COLOR`
- `BRAND_LOGO_PATH`, `BRAND_ICON_PATH`, `BRAND_WALLPAPER_PATH`

**System Paths:**
- `BRAND_CONFIG_DIR` - System config directory (/etc/nubifer)
- `BRAND_DATA_DIR` - System data directory (/usr/share/nubifer)
- `BRAND_LIB_DIR` - System library directory (/usr/lib/nubifer)
- `BRAND_LOG_DIR` - System log directory (/var/log/nubifer)
- `BRAND_USER_CONFIG_DIR` - User config directory (~/.config/nubifer)
- `BRAND_USER_DATA_DIR` - User data directory (~/.local/share/nubifer)

**Component Names:**
- `BRAND_CREDENTIAL_MANAGER` - nubifer-credential-manager
- `BRAND_CONTEXT_MANAGER` - nubifer-context-manager
- `BRAND_RESOURCE_VIEWER` - NubiferOS Resource Viewer
- `BRAND_CONTEXT_INDICATOR` - NubiferOS Context Indicator

**Namespaces:**
- `BRAND_PACKAGE_PREFIX` - Package naming prefix
- `BRAND_SERVICE_PREFIX` - Systemd service prefix
- `BRAND_DBUS_NAMESPACE` - D-Bus namespace (org.nubifer)

## Rebranding

To rebrand the entire distribution:

1. Edit `brand/brand.conf` with new values
2. All scripts that source the brand configuration will automatically use new values
3. No need for find-and-replace across the codebase

## Helper Functions

The `load-brand.sh` script provides helper functions:

### brand_substitute

Substitute brand variables in template files:

```bash
source brand/load-brand.sh
brand_substitute template.txt output.txt
```

### brand_info

Print current brand configuration:

```bash
source brand/load-brand.sh
brand_info
```

Or run directly:

```bash
./brand/load-brand.sh
```

## Best Practices

1. **Always use variables** - Never hardcode "NubiferOS" or "nubifer" in scripts
2. **Source early** - Load brand config at the top of scripts
3. **Export when needed** - Brand variables are auto-exported for child processes
4. **Document usage** - Comment which brand variables your script uses
5. **Test rebranding** - Periodically test changing brand.conf to ensure flexibility

## Examples

### Example 1: Simple Script

```bash
#!/bin/bash
source "$(dirname "$0")/../brand/load-brand.sh"

echo "Welcome to ${BRAND_NAME}!"
echo "${BRAND_TAGLINE}"
```

### Example 2: Systemd Service

```ini
[Unit]
Description=${BRAND_CREDENTIAL_MANAGER}
After=network.target

[Service]
Type=dbus
BusName=${BRAND_DBUS_NAMESPACE}.CredentialManager
ExecStart=/usr/bin/${BRAND_CLI_NAME}-credential-manager
```

### Example 3: Python Configuration

```python
import os

BRAND_NAME = os.getenv('BRAND_NAME', 'NubiferOS')
BRAND_CONFIG_DIR = os.getenv('BRAND_CONFIG_DIR', '/etc/nubifer')
BRAND_DBUS_NAMESPACE = os.getenv('BRAND_DBUS_NAMESPACE', 'org.nubifer')
```

## Updating Brand Assets

When updating visual assets (logos, icons, wallpapers):

1. Place files in appropriate directories
2. Update paths in `brand.conf`
3. Run build scripts to regenerate ISO with new assets

## Name Etymology & Pronunciation

**Nubifer** (NEW-bih-fer)

**Etymology:**
- From Latin: *nubes* (cloud) + *ferre* (to carry/bear)
- Meaning: "Cloud Bearer" or "Cloud Carrier"
- Pronunciation: **NEW-bih-fer** (rhymes with "Lucifer" but starts with "new")
- Emphasis on first syllable: **NU**-bi-fer

**Breakdown:**
- **Nu-** (from "nubes" = cloud) → "NEW"
- **-bi-** → "bih"
- **-fer** (from "ferre" = to carry/bear) → "fer" (like "fur")

The name reflects the distribution's purpose: carrying and managing cloud workloads across multiple cloud providers.

## Version History

- **1.0 (Nimbus)** - Initial release
  - Brand name: NubiferOS
  - Tagline: "Multi-Cloud, Unified Control"


## Visual Assets

### Logo and Icons

The `logo.svg` file contains the main NubiferOS logo featuring:
- Cloud shape representing multi-cloud capability
- Shield with lock representing security
- Blue gradient color scheme
- Scalable vector format

### Wallpapers

Provider-specific wallpapers in `wallpapers/` directory:
- `default.svg` - Default NubiferOS wallpaper (dark blue)
- `aws.svg` - AWS-themed wallpaper (orange #FF9900)
- `azure.svg` - Azure-themed wallpaper (blue #0078D4)
- `gcp.svg` - GCP-themed wallpaper (multi-color)
- `oracle.svg` - Oracle-themed wallpaper (red #FF0000)

All wallpapers feature:
- Dark backgrounds for reduced eye strain
- Subtle gradients and patterns
- Provider-specific color accents
- Minimal text for professional appearance
- 1920x1080 base resolution (scalable)

### Generating PNG Images

Convert SVG files to PNG format:

```bash
cd brand
./generate-images.sh
```

This creates:
- Logo icons: 32px, 64px, 128px, 256px, 512px
- Wallpapers: 1920x1080, 2560x1440, 3840x2160

**Requirements:**
- ImageMagick: `sudo apt-get install imagemagick`
- Inkscape (optional, better quality): `sudo apt-get install inkscape`

### Installation Paths

Generated images are installed to:
- `/usr/share/pixmaps/nubiferos/` - Logo icons
- `/usr/share/backgrounds/nubiferos/` - Wallpapers
- `/usr/share/nubiferos/brand/` - Branding configuration

## Design Guidelines

### Color Palette

**NubiferOS Brand Colors:**
- Primary: Deep Blue (#1e3a8a)
- Secondary: Sky Blue (#3b82f6)
- Accent: Green (#10b981)
- Dark: Slate (#0f172a)
- Light: Gray (#e2e8f0)

**Provider Colors:**
- AWS: Orange (#FF9900)
- Azure: Blue (#0078D4)
- GCP: Multi-color (Blue #4285F4, Red #EA4335, Yellow #FBBC04, Green #34A853)
- Oracle: Red (#FF0000)
- Multi-Cloud: Purple (#6B46C1)

### Typography

- **Primary**: Segoe UI, Arial, sans-serif
- **Monospace**: Fira Code, Consolas, monospace
- **Weights**: 300 (light), 400 (regular), 700 (bold)

### Logo Usage

- Minimum size: 32px
- Clear space: 10% of logo size on all sides
- Works in color and monochrome
- Maintain aspect ratio when scaling

## Customization

### Creating Custom Wallpapers

1. Copy an existing SVG from `wallpapers/`
2. Edit colors, gradients, or text
3. Save with descriptive name
4. Run `./generate-images.sh` to create PNG files

### Modifying the Logo

1. Edit `logo.svg` in Inkscape or text editor
2. Maintain 512x512 viewBox
3. Keep design simple and scalable
4. Run `./generate-images.sh` to regenerate icons

## File Formats

**SVG (Source):**
- Vector format, infinitely scalable
- Editable in any SVG editor
- Small file size
- Used as source for all formats

**PNG (Generated):**
- Raster format for actual use
- Multiple resolutions for different displays
- Transparent backgrounds for icons
- Used in desktop environment
