# Debian Download Fix - 404 Error Resolution

## Problem

Build failed with 404 error when downloading Debian ISO:
```
Connecting to cdimage.debian.org...
HTTP request sent, awaiting response... 404 Not Found
```

## Root Cause

The download script was using `current` symlink path which may not exist or point to an incorrect location:
```
https://cdimage.debian.org/debian-cd/current/amd64/iso-cd
```

Debian's CDN structure changed, and the `current` symlink is not always reliable.

## Solution

Updated `build/download-debian.sh` to try multiple mirror paths in order:

1. **Archive path** - For specific released versions (12.8.0, 12.7.0)
2. **Release path** - For current stable releases
3. **Current symlink** - Fallback option

### Mirror Path Priority:

```bash
DEBIAN_MIRROR_PATHS=(
    "https://cdimage.debian.org/cdimage/archive/12.8.0/amd64/iso-cd"
    "https://cdimage.debian.org/cdimage/archive/12.7.0/amd64/iso-cd"
    "https://cdimage.debian.org/cdimage/release/12.8.0/amd64/iso-cd"
    "https://cdimage.debian.org/cdimage/release/current/amd64/iso-cd"
)
```

### How It Works:

1. Script tries each mirror path sequentially
2. Tests if `SHA256SUMS` file exists at each path
3. Uses the first working mirror
4. Downloads checksums to discover exact ISO filename
5. Downloads ISO and verifies integrity

### Benefits:

- **Resilient**: Works even if one mirror path is down
- **Version-agnostic**: Discovers actual ISO filename from checksums
- **Reliable**: Uses archive paths that don't change
- **Verifiable**: Still validates checksums and signatures

## Manual Download Option

If all mirrors fail, you can manually download:

1. Visit: https://www.debian.org/CD/netinst/
2. Download: `debian-12.x.x-amd64-netinst.iso`
3. Place in: `downloads/` directory
4. Re-run build script

The script will detect the existing ISO and skip download.

## Testing

To test the download fix:

```bash
# Clean previous downloads
rm -rf downloads/

# Run download script
sudo ./build/download-debian.sh

# Should see:
# ✓ Found working mirror: https://cdimage.debian.org/...
# Downloading SHA256 checksums...
# Detected version: 12.x.x
# Downloading Debian ISO...
# ✓ Checksum verification PASSED
```

## Related Files

- `build/download-debian.sh` - Download script with mirror fallback
- `build/config.sh` - Debian version configuration (BASE_VERSION=12)
- `downloads/` - Download directory for ISOs

## Future Improvements

Consider adding:
- Local mirror support
- Torrent download option
- Cached ISO reuse across builds
- Alternative Debian mirrors (country-specific)
