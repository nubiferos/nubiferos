# NubiferOS Calamares Slideshow

This document describes the custom slideshow implementation for the NubiferOS installer.

## Overview

The slideshow displays 15 informational slides during the installation process, educating users about NubiferOS features while the system is being installed.

## Slide Content

The slideshow includes:
- **Security Features (40%)**: 6 slides covering workspace isolation, encryption, read-only mode, battle-tested security, Wayland security, and Firejail isolation
- **Benefits (40%)**: 6 slides covering visual context, zero configuration, disaster prevention, privacy, open source, and CLI wrappers
- **Technical Facts (20%)**: 3 slides covering Debian foundation, welcome message, and completion message

## Slide Timing

- **Duration**: 35 seconds per slide
- **Total Runtime**: ~8.75 minutes for all 15 slides
- **Looping**: Slides loop automatically if installation takes longer

## Slide List

1. **Welcome** - Introduction to NubiferOS
2. **Workspace Isolation** - Firejail namespace isolation
3. **Visual Context** - Context indicator feature
4. **Triple-Layer Encryption** - LUKS + GPG + Keyring
5. **Read-Only Mode** - System-level write protection
6. **Zero Configuration** - Pre-installed cloud tools
7. **Battle-Tested Security** - Proven security tools
8. **Prevent Disasters** - Wrong-account protection
9. **Privacy First** - No telemetry or data collection
10. **Built on Debian** - Debian 12 foundation
11. **Wayland Security** - Keylogging prevention
12. **Firejail Isolation** - Linux namespace details
13. **Open Source** - Transparency and auditability
14. **CLI Wrappers** - Secure credential injection
15. **Almost Done** - Completion message

## Color Scheme

The slideshow uses NubiferOS brand colors:

- **Background**: `#2c3e50` (dark blue-gray)
- **Primary Text**: `#ecf0f1` (light gray)
- **Secondary Text**: `#bdc3c7` (medium gray)
- **Accent Colors**:
  - Blue (`#3498db`): General features, AWS references
  - Red (`#e74c3c`): Security features
  - Green (`#27ae60`): Benefits, completion
  - Orange (`#e67e22`): Warnings, cost savings
  - Purple (`#9b59b6`): Privacy features
  - Teal (`#16a085`): Technical features

## Icons

Each slide includes an emoji icon for visual interest:
- ☁️ Cloud/Welcome
- 🔒 Security/Encryption
- 👁️ Visibility/Context
- 🔐 Credentials
- 🛡️ Protection
- ⚡ Speed/Efficiency
- ✅ Verification
- 💰 Cost Savings
- 🐧 Linux/Debian
- 🖥️ Desktop/Wayland
- 📦 Containers/Isolation
- 📖 Documentation/Open Source
- 🔧 Tools/Configuration
- ✨ Completion

## Technical Implementation

### File Structure

```
installer/calamares/branding/nubiferos/
├── branding.desc          # Main branding configuration
├── show.qml               # Slideshow QML implementation
├── SLIDESHOW.md           # This documentation
└── lang/
    └── calamares_en.ts    # Translation file
```

### QML Implementation

The slideshow uses:
- **QtQuick 2.0**: Basic QML framework
- **calamares.slideshow 1.0**: Calamares slideshow API
- **Simple Layout**: Rectangle + Column + Text (no complex animations)
- **Timer**: 35-second intervals for slide advancement

### Why This Approach?

Previous attempts with complex QML slideshows caused threading segfaults in Calamares. This implementation:
- Uses minimal QML features
- Avoids animations and transitions
- Uses simple text and color layouts
- Follows Calamares slideshow API 2 specification

## Testing

To test the slideshow:

1. Build the NubiferOS ISO:
   ```bash
   sudo ./build-nubiferos.sh
   ```

2. Boot the ISO in VirtualBox or QEMU:
   ```bash
   cd testing
   ./qemu-test.sh
   ```

3. Start the installer and proceed through the installation steps

4. Verify:
   - All 15 slides appear during installation
   - Text is readable (high contrast)
   - Timing feels natural (35 seconds per slide)
   - Slides loop if installation takes longer than expected
   - No crashes or threading errors

## Troubleshooting

### Slideshow Not Appearing

1. Check that `show.qml` exists in the branding directory
2. Verify `branding.desc` has `slideshow: "show.qml"` enabled
3. Check Calamares logs: `/var/log/calamares.log`

### Threading Errors

If you encounter threading segfaults:
1. Disable the slideshow in `branding.desc`:
   ```yaml
   # slideshow: "show.qml"
   ```
2. Report the issue with Calamares version and error logs

### Text Not Readable

Adjust font sizes in `show.qml`:
- Title: `font.pixelSize: 32`
- Subtitle: `font.pixelSize: 18`
- Body: `font.pixelSize: 16`

### Slides Too Fast/Slow

Adjust timer interval in `show.qml`:
```qml
Timer {
    interval: 35000  // milliseconds (35 seconds)
    ...
}
```

## Customization

To customize the slideshow:

1. **Add/Remove Slides**: Edit `show.qml` and add/remove `Slide` blocks
2. **Change Colors**: Modify `color` properties in Rectangle and Text elements
3. **Adjust Timing**: Change `interval` in the Timer
4. **Update Text**: Edit the `text` properties in Text elements
5. **Add Images**: Add Image elements (but keep it simple to avoid threading issues)

## Future Enhancements

Potential improvements:
- Add NubiferOS logo to each slide
- Include cloud provider logos (AWS, Azure, GCP)
- Add subtle fade transitions (if threading issues are resolved)
- Localization support for multiple languages
- Dynamic slide selection based on installation options

## References

- [Calamares Branding Documentation](https://github.com/calamares/calamares/blob/master/src/branding/README.md)
- [QML Documentation](https://doc.qt.io/qt-5/qtqml-index.html)
- [Calamares Slideshow API](https://github.com/calamares/calamares/blob/master/src/libcalamaresui/Branding.h)
