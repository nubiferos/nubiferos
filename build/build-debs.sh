#!/bin/bash
# Build .deb packages for all NubiferOS components
# Usage: ./build/build-debs.sh [version]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="${PROJECT_ROOT}/output/debs"

# Version: use arg, or VERSION file, or brand.conf
VERSION="${1:-$(cat "${PROJECT_ROOT}/VERSION" 2>/dev/null | tr -d '\n')}"
if [ -z "$VERSION" ] || [ "$VERSION" = "0.0.1-dev" ]; then
    VERSION=$(grep 'BRAND_VERSION=' "${PROJECT_ROOT}/brand/brand.conf" | cut -d'"' -f2)
fi
GIT_COMMIT=$(git -C "$PROJECT_ROOT" rev-parse --short HEAD 2>/dev/null || echo "unknown")

echo "=========================================="
echo "Building NubiferOS .deb packages"
echo "Version: ${VERSION} (${GIT_COMMIT})"
echo "=========================================="

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/build"

# Helper: set version in control file and build
build_package() {
    local pkg_name="$1"
    local pkg_src="${PROJECT_ROOT}/packaging/${pkg_name}"
    local build_dir="${OUTPUT_DIR}/build/${pkg_name}"

    echo ""
    echo "--- Building ${pkg_name} ---"

    # Copy packaging skeleton
    rm -rf "$build_dir"
    cp -r "$pkg_src" "$build_dir"

    # Set version
    sed -i "s/__VERSION__/${VERSION}/g" "$build_dir/DEBIAN/control"

    # Make maintainer scripts executable
    for script in postinst preinst postrm prerm; do
        [ -f "$build_dir/DEBIAN/$script" ] && chmod 755 "$build_dir/DEBIAN/$script"
    done

    # Build
    dpkg-deb --build --root-owner-group "$build_dir" "${OUTPUT_DIR}/${pkg_name}_${VERSION}_all.deb"
    echo "  -> ${pkg_name}_${VERSION}_all.deb"
}

# ============================================
# 1. nubifer-core
# ============================================
PKG="${PROJECT_ROOT}/packaging/nubifer-core"

# Scripts
mkdir -p "$PKG/usr/local/bin"
cp "$PROJECT_ROOT/scripts/nubifer-setup-wizard" "$PKG/usr/local/bin/"
cp "$PROJECT_ROOT/scripts/nubifer-update-checker" "$PKG/usr/local/bin/"
cp "$PROJECT_ROOT/scripts/nubifer-check-updates" "$PKG/usr/local/bin/"
cp "$PROJECT_ROOT/scripts/nubifer-security-scan" "$PKG/usr/local/bin/"
cp "$PROJECT_ROOT/scripts/nubifer-bookmarks" "$PKG/usr/local/bin/"
cp "$PROJECT_ROOT/scripts/install-cloud-sdks.sh" "$PKG/usr/local/bin/install-cloud-sdks"
cp "$PROJECT_ROOT/scripts/install-ides.sh" "$PKG/usr/local/bin/install-ides"
cp "$PROJECT_ROOT/configs/ide/install-ide-plugins.sh" "$PKG/usr/local/bin/install-ide-plugins"
chmod +x "$PKG/usr/local/bin/"*

# Data files
mkdir -p "$PKG/usr/share/nubifer"
cp "$PROJECT_ROOT/scripts/tools-config.yaml" "$PKG/usr/share/nubifer/"
cat > "$PKG/usr/share/nubifer/VERSION.txt" << EOF
NubiferOS System Information
=============================
Version: ${VERSION}
Git Commit: ${GIT_COMMIT}
Build Date: $(date +%Y-%m-%d\ %H:%M:%S)
EOF

# Browser config
mkdir -p "$PKG/usr/share/nubifer/browser"
cp "$PROJECT_ROOT/configs/browser/firefox-bookmarks.json" "$PKG/usr/share/nubifer/browser/"
cp "$PROJECT_ROOT/configs/browser/firefox-hardening.js" "$PKG/usr/share/nubifer/browser/"

# NubiferOS config
mkdir -p "$PKG/etc/nubiferos/providers"
cp "$PROJECT_ROOT/configs/nubiferos/nubiferos.conf" "$PKG/etc/nubiferos/"
cp "$PROJECT_ROOT/configs/nubiferos/providers/"*.conf "$PKG/etc/nubiferos/providers/"

# Shell integration
mkdir -p "$PKG/etc/nubifer"
cp "$PROJECT_ROOT/components/workspace-manager/shell-integration.sh" "$PKG/etc/nubifer/"

# Desktop integration
mkdir -p "$PKG/usr/share/desktop-directories"
mkdir -p "$PKG/etc/xdg/menus/applications-merged"
mkdir -p "$PKG/usr/share/applications"
mkdir -p "$PKG/usr/share/icons/hicolor/scalable/apps"

for f in "$PROJECT_ROOT/configs/desktop/applications/"*.directory; do
    [ -f "$f" ] && cp "$f" "$PKG/usr/share/desktop-directories/"
done
[ -f "$PROJECT_ROOT/configs/desktop/menus/nubiferos-applications.menu" ] && \
    cp "$PROJECT_ROOT/configs/desktop/menus/nubiferos-applications.menu" \
       "$PKG/etc/xdg/menus/applications-merged/"
for f in "$PROJECT_ROOT/configs/desktop/applications/"*.desktop; do
    [ -f "$f" ] && cp "$f" "$PKG/usr/share/applications/"
done
for f in "$PROJECT_ROOT/brand/icons/"*.svg; do
    [ -f "$f" ] && cp "$f" "$PKG/usr/share/icons/hicolor/scalable/apps/"
done

# Docs
mkdir -p "$PKG/usr/share/doc/nubifer"
cp "$PROJECT_ROOT"/docs/*.md "$PKG/usr/share/doc/nubifer/" 2>/dev/null || true

# Man pages
mkdir -p "$PKG/usr/share/man/man1"
if [ -f "$PROJECT_ROOT/docs/man/nubifer-security-scan.1" ]; then
    cp "$PROJECT_ROOT/docs/man/nubifer-security-scan.1" "$PKG/usr/share/man/man1/"
    gzip -f "$PKG/usr/share/man/man1/nubifer-security-scan.1" 2>/dev/null || true
fi

# Tmpfiles
mkdir -p "$PKG/etc/tmpfiles.d"
cp "$PROJECT_ROOT/configs/system/xdg-runtime-root.conf" "$PKG/etc/tmpfiles.d/"

# Installer helper scripts
mkdir -p "$PKG/usr/share/nubifer/installer"
for f in post-install-workspace.sh enable-firejail-wrappers.sh disable-firejail-wrappers.sh; do
    [ -f "$PROJECT_ROOT/installer/$f" ] && cp "$PROJECT_ROOT/installer/$f" "$PKG/usr/share/nubifer/installer/"
done
chmod +x "$PKG/usr/share/nubifer/installer/"*.sh 2>/dev/null || true

# Tool installer scripts
mkdir -p "$PKG/usr/share/nubiferos/installers"
for script in "$PROJECT_ROOT/scripts/installers/"*.sh; do
    [ -f "$script" ] && cp "$script" "$PKG/usr/share/nubiferos/installers/"
done
chmod +x "$PKG/usr/share/nubiferos/installers/"*.sh 2>/dev/null || true

build_package "nubifer-core"

# ============================================
# 2. nubifer-creds
# ============================================
PKG="${PROJECT_ROOT}/packaging/nubifer-creds"

mkdir -p "$PKG/usr/local/bin"
cp "$PROJECT_ROOT/components/credential-manager/nubifer-creds" "$PKG/usr/local/bin/"
chmod +x "$PKG/usr/local/bin/nubifer-creds"

if [ -f "$PROJECT_ROOT/components/credential-manager/nubifer-aws-credential-helper" ]; then
    cp "$PROJECT_ROOT/components/credential-manager/nubifer-aws-credential-helper" "$PKG/usr/local/bin/"
    chmod +x "$PKG/usr/local/bin/nubifer-aws-credential-helper"
fi

# Token cache / STS support
mkdir -p "$PKG/usr/local/lib/nubifer/credential-manager/src/token_generators"
cp "$PROJECT_ROOT/components/credential-manager/src/token_cache.py" \
   "$PKG/usr/local/lib/nubifer/credential-manager/src/" 2>/dev/null || true
cp "$PROJECT_ROOT/components/credential-manager/src/token_generators/"*.py \
   "$PKG/usr/local/lib/nubifer/credential-manager/src/token_generators/" 2>/dev/null || true

build_package "nubifer-creds"

# ============================================
# 3. nubifer-workspace
# ============================================
PKG="${PROJECT_ROOT}/packaging/nubifer-workspace"

mkdir -p "$PKG/usr/local/bin"
cp "$PROJECT_ROOT/components/workspace-manager/nubifer-workspace" "$PKG/usr/local/bin/"
chmod +x "$PKG/usr/local/bin/nubifer-workspace"

# Context manager
mkdir -p "$PKG/usr/local/lib/nubiferos/context-manager"
cp "$PROJECT_ROOT/components/context-manager/src/"*.py "$PKG/usr/local/lib/nubiferos/context-manager/"

# GNOME desktop integration
mkdir -p "$PKG/usr/local/lib/nubiferos"
cp "$PROJECT_ROOT/components/workspace-manager/gnome-desktop-integration.py" "$PKG/usr/local/lib/nubiferos/"
chmod +x "$PKG/usr/local/lib/nubiferos/gnome-desktop-integration.py"

# Service wrappers
cat > "$PKG/usr/local/bin/nubifer-context-service" << 'EOF'
#!/bin/bash
INSTALL_DIR="/usr/local/lib/nubiferos/context-manager"
export PYTHONPATH="$INSTALL_DIR:$PYTHONPATH"
exec python3 "$INSTALL_DIR/dbus_interface.py" "$@"
EOF
chmod +x "$PKG/usr/local/bin/nubifer-context-service"

cat > "$PKG/usr/local/bin/nubifer-desktop" << 'EOF'
#!/bin/bash
exec python3 /usr/local/lib/nubiferos/gnome-desktop-integration.py "$@"
EOF
chmod +x "$PKG/usr/local/bin/nubifer-desktop"

# D-Bus service
mkdir -p "$PKG/usr/share/dbus-1/services"
cat > "$PKG/usr/share/dbus-1/services/org.nubiferos.ContextManager.service" << 'EOF'
[D-BUS Service]
Name=org.nubiferos.ContextManager
Exec=/usr/local/bin/nubifer-context-service
EOF

# Systemd user service
mkdir -p "$PKG/usr/lib/systemd/user"
cp "$PROJECT_ROOT/components/context-manager/systemd/nubifer-context-manager.service" \
   "$PKG/usr/lib/systemd/user/"

# Firejail profiles
mkdir -p "$PKG/etc/firejail/nubifer"
cp "$PROJECT_ROOT/components/workspace-manager/firejail-profiles/"*.profile \
   "$PKG/etc/firejail/nubifer/" 2>/dev/null || true

# Firejail wrapper and CLI wrappers
mkdir -p "$PKG/usr/local/lib/nubifer/cli-wrappers"
cp "$PROJECT_ROOT/components/workspace-manager/firejail-wrapper.sh" "$PKG/usr/local/lib/nubifer/"
chmod +x "$PKG/usr/local/lib/nubifer/firejail-wrapper.sh"
cp "$PROJECT_ROOT/components/workspace-manager/cli-wrappers/"* "$PKG/usr/local/lib/nubifer/cli-wrappers/" 2>/dev/null || true
chmod +x "$PKG/usr/local/lib/nubifer/cli-wrappers/"* 2>/dev/null || true

build_package "nubifer-workspace"

# ============================================
# 4. nubifer-dashboard
# ============================================
PKG="${PROJECT_ROOT}/packaging/nubifer-dashboard"

mkdir -p "$PKG/usr/local/bin"
cp "$PROJECT_ROOT/components/security-dashboard/nubifer-dashboard" "$PKG/usr/local/bin/"
chmod +x "$PKG/usr/local/bin/nubifer-dashboard"

mkdir -p "$PKG/usr/share/applications"
cp "$PROJECT_ROOT/components/security-dashboard/nubifer-dashboard.desktop" "$PKG/usr/share/applications/"

mkdir -p "$PKG/etc/xdg/autostart"
cp "$PROJECT_ROOT/components/security-dashboard/nubifer-dashboard-autostart.desktop" "$PKG/etc/xdg/autostart/"

build_package "nubifer-dashboard"

# ============================================
# 5. nubifer-tools
# ============================================
PKG="${PROJECT_ROOT}/packaging/nubifer-tools"

mkdir -p "$PKG/usr/local/bin"
cp "$PROJECT_ROOT/components/cloud-tools-launcher/nubifer-tools" "$PKG/usr/local/bin/"
chmod +x "$PKG/usr/local/bin/nubifer-tools"

mkdir -p "$PKG/usr/bin"
cp "$PROJECT_ROOT/components/software-center/nubifer-software" "$PKG/usr/bin/"
chmod +x "$PKG/usr/bin/nubifer-software"

mkdir -p "$PKG/usr/share/applications"
cp "$PROJECT_ROOT/components/cloud-tools-launcher/nubifer-tools.desktop" "$PKG/usr/share/applications/"
cp "$PROJECT_ROOT/components/software-center/nubifer-software.desktop" "$PKG/usr/share/applications/"

build_package "nubifer-tools"

# ============================================
# 6. nubifer-welcome
# ============================================
PKG="${PROJECT_ROOT}/packaging/nubifer-welcome"

mkdir -p "$PKG/usr/local/bin"
cp "$PROJECT_ROOT/components/first-boot-wizard/nubifer-welcome" "$PKG/usr/local/bin/"
chmod +x "$PKG/usr/local/bin/nubifer-welcome"

build_package "nubifer-welcome"

# ============================================
# 7. nubifer-updater
# ============================================
PKG="${PROJECT_ROOT}/packaging/nubifer-updater"

# APT source list
mkdir -p "$PKG/etc/apt/sources.list.d"
cat > "$PKG/etc/apt/sources.list.d/nubiferos.list" << 'EOF'
deb [signed-by=/etc/apt/keyrings/nubiferos.gpg] https://packages.nubiferos.org bookworm main
EOF

mkdir -p "$PKG/etc/apt/keyrings"

# Systemd timer for periodic updates
mkdir -p "$PKG/usr/lib/systemd/system"

cat > "$PKG/usr/lib/systemd/system/nubifer-update.service" << 'EOF'
[Unit]
Description=NubiferOS Package Update Check
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/nubifer-update-service
EOF

cat > "$PKG/usr/lib/systemd/system/nubifer-update.timer" << 'EOF'
[Unit]
Description=NubiferOS Update Check Timer

[Timer]
OnBootSec=5min
OnUnitActiveSec=6h
RandomizedDelaySec=30min
Persistent=true

[Install]
WantedBy=timers.target
EOF

# Update service script
mkdir -p "$PKG/usr/local/bin"
cat > "$PKG/usr/local/bin/nubifer-update-service" << 'UPDATER'
#!/bin/bash
# NubiferOS Update Service - checks for and applies package updates
set -euo pipefail

LOG_TAG="nubifer-update"
STAMP_FILE="/var/lib/nubifer/last-update-check"

log() { logger -t "$LOG_TAG" "$1"; }

log "Checking for NubiferOS package updates..."

# Update package lists
if ! apt-get update -o Dir::Etc::sourcelist=/etc/apt/sources.list.d/nubiferos.list \
     -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0" -qq 2>/dev/null; then
    log "WARNING: Failed to update NubiferOS package list"
    exit 1
fi

# Check for upgradable nubifer packages
UPGRADABLE=$(apt list --upgradable 2>/dev/null | grep -c "^nubifer-" || true)

if [ "$UPGRADABLE" -gt 0 ]; then
    log "Found ${UPGRADABLE} NubiferOS package update(s), installing..."

    DEBIAN_FRONTEND=noninteractive apt-get install -y --only-upgrade \
        nubifer-core nubifer-creds nubifer-workspace nubifer-dashboard \
        nubifer-tools nubifer-welcome nubifer-updater 2>/dev/null || true

    log "NubiferOS packages updated successfully"

    # Notify logged-in users
    for user_id in $(loginctl list-users --no-legend 2>/dev/null | awk '{print $1}'); do
        user_name=$(loginctl show-user "$user_id" -p Name --value 2>/dev/null || true)
        if [ -n "$user_name" ]; then
            sudo -u "$user_name" DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u "$user_name")/bus" \
                notify-send "NubiferOS Updated" "System packages have been updated. Some changes may require logout." \
                --icon=system-software-update 2>/dev/null || true
        fi
    done
else
    log "All NubiferOS packages are up to date"
fi

# Update timestamp
mkdir -p "$(dirname "$STAMP_FILE")"
date -Iseconds > "$STAMP_FILE"
UPDATER
chmod +x "$PKG/usr/local/bin/nubifer-update-service"

build_package "nubifer-updater"

# ============================================
# Summary
# ============================================
echo ""
echo "=========================================="
echo "Build complete!"
echo "=========================================="
echo ""
ls -lh "$OUTPUT_DIR"/*.deb
echo ""
echo "Total packages: $(ls "$OUTPUT_DIR"/*.deb | wc -l)"

# Cleanup build dirs
rm -rf "$OUTPUT_DIR/build"
