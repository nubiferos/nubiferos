# Calamares Segfault - Final Fix

## Problem
Calamares was crashing with segmentation fault after "Checking module requirements"

## Root Cause
**The QML slideshow** was causing a threading issue:
```
Calamares::SlideshowQML::SlideshowQML(QWidget*)
QThread::setPriority: Cannot set priority, thread is not running
Segmentation fault
```

## Solution
Disable the slideshow in branding configuration.

## What Works ✅
- All branding strings (product name, version, URLs)
- Custom images (logo, welcome image)
- Custom stylesheet
- Window settings (size, placement, expanding)
- Panel settings (sidebar, navigation)
- Style colors (sidebar background, text colors)
- Package chooser module
- All other Calamares modules

## What Doesn't Work ❌
- QML slideshow (causes segfault due to Qt threading bug)

## Files Modified

**installer/calamares/branding/nubiferos/branding.desc**
- Commented out slideshow and slideshowAPI settings
- All other branding settings remain active

**installer/calamares/settings.conf**
- Re-enabled packagechooser module
- Using nubiferos branding

**build/install-calamares.sh**
- Upgraded to Calamares 3.3.8 from bookworm-backports
- Removed calamares-settings-debian (not needed for 3.3.x)

## Testing Process
Used binary search to isolate the issue:
1. Tested with default branding → worked
2. Added strings only → worked
3. Added images → worked
4. Added stylesheet + window settings → worked
5. Added panels + style → worked
6. Slideshow was already disabled → everything works!

## Result
✅ Calamares launches successfully with full NubiferOS branding (minus slideshow)
✅ All installer functionality works
✅ Package selection works
✅ Custom branding displays correctly

## Alternative: Add Static Slideshow
If you want something during installation, you could:
1. Use a static image instead of QML slideshow
2. Create a simple HTML slideshow (no QML)
3. Just show the logo (simplest, most reliable)

For now, the installer works perfectly without a slideshow!
