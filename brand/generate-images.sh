#!/bin/bash
# Generate PNG images from SVG sources for NubiferOS branding

set -e

echo "Generating NubiferOS branding images..."
echo "========================================"

# Check if ImageMagick is installed
if ! command -v convert &> /dev/null; then
    echo "ImageMagick not found. Installing..."
    sudo apt-get update
    sudo apt-get install -y imagemagick
fi

# Check if Inkscape is installed (better SVG rendering)
if command -v inkscape &> /dev/null; then
    CONVERTER="inkscape"
    echo "Using Inkscape for SVG conversion (better quality)"
else
    CONVERTER="imagemagick"
    echo "Using ImageMagick for SVG conversion"
fi

# Create output directories
mkdir -p wallpapers/png
mkdir -p icons

echo ""
echo "Converting logo..."
if [ "$CONVERTER" = "inkscape" ]; then
    inkscape logo.svg --export-filename=icons/logo-512.png --export-width=512 --export-height=512
    inkscape logo.svg --export-filename=icons/logo-256.png --export-width=256 --export-height=256
    inkscape logo.svg --export-filename=icons/logo-128.png --export-width=128 --export-height=128
    inkscape logo.svg --export-filename=icons/logo-64.png --export-width=64 --export-height=64
    inkscape logo.svg --export-filename=icons/logo-32.png --export-width=32 --export-height=32
else
    convert logo.svg -resize 512x512 icons/logo-512.png
    convert logo.svg -resize 256x256 icons/logo-256.png
    convert logo.svg -resize 128x128 icons/logo-128.png
    convert logo.svg -resize 64x64 icons/logo-64.png
    convert logo.svg -resize 32x32 icons/logo-32.png
fi
echo "✓ Logo icons generated (32px to 512px)"

echo ""
echo "Converting wallpapers..."

# Wallpaper resolutions
RESOLUTIONS=(
    "1920x1080"  # Full HD
    "2560x1440"  # QHD
    "3840x2160"  # 4K
)

WALLPAPERS=(
    "default"
    "aws"
    "azure"
    "gcp"
    "oracle"
)

for wallpaper in "${WALLPAPERS[@]}"; do
    echo "  Converting ${wallpaper}..."
    
    for res in "${RESOLUTIONS[@]}"; do
        if [ "$CONVERTER" = "inkscape" ]; then
            width=$(echo $res | cut -d'x' -f1)
            height=$(echo $res | cut -d'x' -f2)
            inkscape "wallpapers/${wallpaper}.svg" \
                --export-filename="wallpapers/png/${wallpaper}-${res}.png" \
                --export-width=$width \
                --export-height=$height
        else
            convert "wallpapers/${wallpaper}.svg" \
                -resize $res \
                "wallpapers/png/${wallpaper}-${res}.png"
        fi
    done
    
    echo "    ✓ ${wallpaper} (1080p, 1440p, 4K)"
done

echo ""
echo "========================================"
echo "✓ All images generated!"
echo "========================================"
echo ""
echo "Generated files:"
echo "  Logo icons: brand/icons/logo-*.png"
echo "  Wallpapers: brand/wallpapers/png/*-*.png"
echo ""
echo "Sizes:"
echo "  Icons: 32px, 64px, 128px, 256px, 512px"
echo "  Wallpapers: 1920x1080, 2560x1440, 3840x2160"
echo ""
echo "Usage:"
echo "  - Copy icons to /usr/share/pixmaps/ or /usr/share/icons/"
echo "  - Copy wallpapers to /usr/share/backgrounds/nubiferos/"
echo "  - Set as desktop background in GNOME settings"
echo ""
