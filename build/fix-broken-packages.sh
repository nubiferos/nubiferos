#!/bin/bash
# Fix broken package state in chroot
# Run this if dpkg is in a broken state

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../brand/load-brand.sh"
source "${SCRIPT_DIR}/config.sh"

init_config

CHROOT_DIR="${PROJECT_ROOT}/work/chroot"

if [ ! -d "${CHROOT_DIR}" ]; then
    echo "Chroot directory not found: ${CHROOT_DIR}"
    exit 1
fi

echo "Fixing broken packages in chroot..."

# Remove problematic packages
chroot "${CHROOT_DIR}" /bin/bash -c "
    dpkg --remove --force-remove-reinstreq emacs emacs-gtk dictionaries-common aspell aspell-en hunspell-en-us emacsen-common 2>/dev/null || true
    apt-get clean
    apt-get update
    dpkg --configure -a
    apt-get install -f -y
"

echo "✓ Package state fixed"
echo "You can now re-run the build"
