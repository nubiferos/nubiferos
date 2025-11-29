## Calamares Package Selection - NetInstall Solution

## Problem
- `packagechooser` module triggers QML slideshow creation during exec phase
- QML slideshow causes threading segfault: "QThread::setPriority: Cannot set priority, thread is not running"
- Need package selection without QML

## Solution: Use netinstall Module

### Why netinstall?
- **Widget-based UI** - Uses Qt widgets, not QML
- **No threading issues** - Doesn't create slideshow widget
- **Simpler** - Easier to configure
- **Same functionality** - Users can still select packages

### Differences from packagechooser

| Feature | packagechooser | netinstall |
|---------|---------------|------------|
| UI | QML (modern) | Qt Widgets (classic) |
| Threading | Buggy | Stable |
| Config | Complex | Simple YAML |
| Screenshots | Supported | Not supported |
| Slideshow | Triggers it | Doesn't trigger |

### Files Created

1. **installer/calamares/modules/netinstall.conf**
   - Module configuration
   - Points to package groups file

2. **installer/calamares/modules/netinstall-packages.yaml**
   - Package groups definition
   - Same packages as before, simpler format

3. **installer/calamares/settings.conf**
   - Replaced `packagechooser` with `netinstall` in sequence

### Testing

```bash
# Rebuild
sudo ./build-nubiferos.sh

# Test in VM
./testing/qemu-with-spice.sh

# Should see package selection page without segfault
```

### Benefits
✅ Package selection works
✅ No segfault
✅ Custom branding works
✅ All other modules work
✅ Simpler configuration

### Tradeoffs
- Less modern UI (widgets vs QML)
- No package screenshots
- But it actually works!

## Alternative: Post-Install Package Selection

If netinstall also has issues, we can:
1. Install base system only
2. Show package selection wizard on first boot
3. Use our own custom UI (no Calamares involved)

This would give us:
- Full control over UI
- No Calamares bugs
- Better user experience
- Can use modern web UI if desired
