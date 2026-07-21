#!/bin/bash
# Build .deb packages for all NubiferOS components
# Usage: ./build/build-debs.sh [version]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="${PROJECT_ROOT}/output/debs"

# Version: use arg, or VERSION file, or brand.conf
VERSION="${1:-$(cat "${PROJECT_ROOT}/VERSION" 2>/dev/null | tr -d '\n')}"
if [ -z "$VERSION" ]; then
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
sed -i "s/@VERSION@/${VERSION}/g" "$PKG/etc/nubiferos/nubiferos.conf"
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

# Audit trail
mkdir -p "$PKG/etc/nubifer"
cp "$PROJECT_ROOT/components/audit-trail/audit-functions.sh" "$PKG/etc/nubifer/"
cp "$PROJECT_ROOT/components/audit-trail/schema.sql" "$PKG/etc/nubifer/audit-schema.sql"
cp "$PROJECT_ROOT/components/audit-trail/nubifer-audit" "$PKG/usr/local/bin/"
cp "$PROJECT_ROOT/components/audit-trail/nubifer-audit-viewer" "$PKG/usr/local/bin/"
chmod +x "$PKG/usr/local/bin/nubifer-audit" "$PKG/usr/local/bin/nubifer-audit-viewer"
mkdir -p "$PKG/usr/share/applications"
cp "$PROJECT_ROOT/components/audit-trail/nubifer-audit-viewer.desktop" "$PKG/usr/share/applications/"
# Audit rotation timer
cp "$PROJECT_ROOT/components/audit-trail/systemd/nubifer-audit-rotate.timer" "$PKG/usr/lib/systemd/user/"
cp "$PROJECT_ROOT/components/audit-trail/systemd/nubifer-audit-rotate.service" "$PKG/usr/lib/systemd/user/"

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
cp "$PROJECT_ROOT/components/security-dashboard/nubifer-dashboard-autostart" "$PKG/usr/local/bin/"
chmod 755 "$PKG/usr/local/bin/nubifer-dashboard-autostart"

build_package "nubifer-dashboard"

# ============================================
# 4b. nubifer-resources
# ============================================
PKG="${PROJECT_ROOT}/packaging/nubifer-resources"

# Python modules (db + indexer + GTK app)
mkdir -p "$PKG/usr/local/lib/nubiferos/resource-viewer"
cp "$PROJECT_ROOT/components/resource-viewer/src/db.py" "$PKG/usr/local/lib/nubiferos/resource-viewer/"
cp "$PROJECT_ROOT/components/resource-viewer/src/indexer.py" "$PKG/usr/local/lib/nubiferos/resource-viewer/"
cp "$PROJECT_ROOT/components/resource-viewer/src/nubifer-resources" "$PKG/usr/local/lib/nubiferos/resource-viewer/"
chmod +x "$PKG/usr/local/lib/nubiferos/resource-viewer/nubifer-resources"

# CLI sync wrapper
mkdir -p "$PKG/usr/local/bin"
cat > "$PKG/usr/local/bin/nubifer-resource-sync" << 'EOF'
#!/bin/bash
INSTALL_DIR="/usr/local/lib/nubiferos/resource-viewer"
export PYTHONPATH="$INSTALL_DIR:$PYTHONPATH"
exec python3 "$INSTALL_DIR/indexer.py" "$@"
EOF
chmod +x "$PKG/usr/local/bin/nubifer-resource-sync"

# GUI launcher wrapper
cat > "$PKG/usr/local/bin/nubifer-resources" << 'EOF'
#!/bin/bash
INSTALL_DIR="/usr/local/lib/nubiferos/resource-viewer"
export PYTHONPATH="$INSTALL_DIR:$PYTHONPATH"
exec python3 "$INSTALL_DIR/nubifer-resources" "$@"
EOF
chmod +x "$PKG/usr/local/bin/nubifer-resources"

mkdir -p "$PKG/usr/share/applications"
cp "$PROJECT_ROOT/components/resource-viewer/nubifer-resources.desktop" "$PKG/usr/share/applications/"

build_package "nubifer-resources"

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
        nubifer-resources nubifer-tools nubifer-welcome nubifer-updater \
        nubifer-security nubifer-branding nubifer-ai 2>/dev/null || true

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
# 8. nubifer-security
# ============================================
PKG="${PROJECT_ROOT}/packaging/nubifer-security"

# AppArmor profile for credential manager
mkdir -p "$PKG/etc/apparmor.d"
cat > "$PKG/etc/apparmor.d/nubifer.credential-manager" << 'EOF'
#include <tunables/global>

/usr/bin/nubifer-credential-manager {
  #include <abstractions/base>
  #include <abstractions/python>
  /etc/nubifer/** r,
  owner @{HOME}/.config/nubifer/** rw,
  owner @{HOME}/.local/share/nubifer/** rw,
  #include <abstractions/dbus-session-strict>
  deny network,
  owner @{HOME}/.local/share/keyrings/** rw,
}
EOF

# AppArmor first-boot enforcement service
mkdir -p "$PKG/etc/systemd/system"
cat > "$PKG/etc/systemd/system/apparmor-enforce-profiles.service" << 'EOF'
[Unit]
Description=Enforce AppArmor profiles on first boot
After=apparmor.service
ConditionPathExists=!/var/lib/nubifer/apparmor-enforced

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'aa-enforce /etc/apparmor.d/* 2>/dev/null || true; mkdir -p /var/lib/nubifer; touch /var/lib/nubifer/apparmor-enforced'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# fail2ban config
mkdir -p "$PKG/etc/fail2ban"
cat > "$PKG/etc/fail2ban/jail.local" << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5
destemail = root@localhost
sendername = Fail2Ban
action = %(action_)s

[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 3
bantime = 7200
EOF

# Unattended upgrades
mkdir -p "$PKG/etc/apt/apt.conf.d"
cat > "$PKG/etc/apt/apt.conf.d/50unattended-upgrades" << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::InstallOnShutdown "false";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF

cat > "$PKG/etc/apt/apt.conf.d/20auto-upgrades" << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF

# Audit rules
mkdir -p "$PKG/etc/audit/rules.d"
cat > "$PKG/etc/audit/rules.d/nubifer.rules" << 'EOF'
# NubiferOS Audit Rules
-w /etc/nubifer/ -p wa -k nubifer_config
-w /home/ -p wa -k nubifer_credentials
-w /var/log/auth.log -p wa -k auth_log
-w /etc/passwd -p wa -k passwd_changes
-w /etc/group -p wa -k group_changes
-w /etc/shadow -p wa -k shadow_changes
-w /etc/sudoers -p wa -k sudoers_changes
-w /var/log/sudo.log -p wa -k sudo_log
-w /etc/network/ -p wa -k network_config
-a always,exit -F arch=b64 -S adjtimex -S settimeofday -k time_change
-a always,exit -F arch=b64 -S clock_settime -k time_change
-a always,exit -F arch=b64 -S unlink -S unlinkat -S rename -S renameat -k delete
-w /sbin/insmod -p x -k modules
-w /sbin/rmmod -p x -k modules
-w /sbin/modprobe -p x -k modules
EOF

# Kernel hardening sysctl
mkdir -p "$PKG/etc/sysctl.d"
cat > "$PKG/etc/sysctl.d/99-nubifer-hardening.conf" << 'EOF'
# NubiferOS Kernel Hardening
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.icmp_echo_ignore_all = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_syn_retries = 2
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_max_syn_backlog = 4096
fs.file-max = 65535
net.ipv4.tcp_rfc1337 = 1
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
kernel.yama.ptrace_scope = 2
kernel.unprivileged_bpf_disabled = 1
net.core.bpf_jit_harden = 2
kernel.core_uses_pid = 1
fs.suid_dumpable = 0
kernel.randomize_va_space = 2
kernel.printk = 3 3 3 3
EOF

# SSH hardening
mkdir -p "$PKG/etc/ssh/sshd_config.d"
cat > "$PKG/etc/ssh/sshd_config.d/99-nubifer-hardening.conf" << 'EOF'
# NubiferOS SSH Hardening
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
ChallengeResponseAuthentication no
X11Forwarding no
ClientAliveInterval 300
ClientAliveCountMax 2
MaxAuthTries 3
MaxSessions 2
EOF

# Password quality
mkdir -p "$PKG/etc/security"
cat > "$PKG/etc/security/pwquality.conf" << 'EOF'
# NubiferOS Password Quality Requirements
minlen = 16
dcredit = -1
ucredit = -1
lcredit = -1
ocredit = -1
minclass = 4
maxrepeat = 2
maxsequence = 3
gecoscheck = 1
dictcheck = 1
usercheck = 1
enforcing = 1
retry = 3
EOF

# Security verification script
mkdir -p "$PKG/usr/local/bin"
cat > "$PKG/usr/local/bin/verify-security" << 'VERIFY'
#!/bin/bash
echo "=========================================="
echo "NubiferOS Security Verification"
echo "=========================================="

check_service() {
    local service="$1"
    if systemctl is-enabled "$service" &>/dev/null; then
        echo "✓ $service: enabled"
    else
        echo "✗ $service: not enabled"
    fi
}

echo ""
echo "Security Services:"
check_service "apparmor"
check_service "ufw"
check_service "fail2ban"
check_service "unattended-upgrades"
check_service "auditd"

echo ""
echo "Firewall Status:"
ufw status | head -n 5

echo ""
echo "AppArmor Status:"
aa-status 2>/dev/null | head -n 10 || echo "Run as root to see AppArmor status"

echo ""
echo "=========================================="
VERIFY
chmod +x "$PKG/usr/local/bin/verify-security"

# Security monitoring scripts
for script in anti-theft-protection.sh bios-security-confirm.sh configure-cpu-mitigations.sh \
              enable-retbleed-mitigation.sh recovery-key-setup.sh security-monitor.sh; do
    [ -f "$PROJECT_ROOT/configs/security/$script" ] && \
        cp "$PROJECT_ROOT/configs/security/$script" "$PKG/usr/local/bin/"
done
chmod +x "$PKG/usr/local/bin/"*.sh 2>/dev/null || true

# Security monitor systemd service
if [ -f "$PROJECT_ROOT/configs/security/nubifer-security-monitor.service" ]; then
    mkdir -p "$PKG/usr/lib/systemd/system"
    cp "$PROJECT_ROOT/configs/security/nubifer-security-monitor.service" "$PKG/usr/lib/systemd/system/"
fi

# Reboot-required check script for dashboard integration
cat > "$PKG/usr/local/bin/nubifer-reboot-check" << 'REBOOT'
#!/bin/bash
# Check if a reboot is required and notify
if [ -f /var/run/reboot-required ]; then
    echo "REBOOT_REQUIRED=true"
    if [ -f /var/run/reboot-required.pkgs ]; then
        echo "PACKAGES=$(cat /var/run/reboot-required.pkgs | tr '\n' ',')"
    fi
    # Check if kexec is available for fast reboot
    if command -v kexec >/dev/null 2>&1; then
        echo "KEXEC_AVAILABLE=true"
    else
        echo "KEXEC_AVAILABLE=false"
    fi
else
    echo "REBOOT_REQUIRED=false"
fi
REBOOT
chmod +x "$PKG/usr/local/bin/nubifer-reboot-check"

# Fast reboot script using kexec
cat > "$PKG/usr/local/bin/nubifer-fast-reboot" << 'FASTREBOOT'
#!/bin/bash
# Fast reboot using kexec (loads new kernel without full BIOS/POST)
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Error: must be run as root (use sudo)"
    exit 1
fi

if ! command -v kexec >/dev/null 2>&1; then
    echo "kexec-tools not installed, falling back to normal reboot"
    systemctl reboot
    exit 0
fi

KERNEL=$(ls -t /boot/vmlinuz-* 2>/dev/null | head -1)
INITRD=$(ls -t /boot/initrd.img-* 2>/dev/null | head -1)

if [ -z "$KERNEL" ] || [ -z "$INITRD" ]; then
    echo "Cannot find kernel/initrd, falling back to normal reboot"
    systemctl reboot
    exit 0
fi

CMDLINE=$(cat /proc/cmdline)

echo "Loading new kernel via kexec..."
echo "  Kernel: $KERNEL"
echo "  Initrd: $INITRD"
kexec -l "$KERNEL" --initrd="$INITRD" --command-line="$CMDLINE"

echo "Executing fast reboot..."
systemctl kexec
FASTREBOOT
chmod +x "$PKG/usr/local/bin/nubifer-fast-reboot"

build_package "nubifer-security"

# ============================================
# 9. nubifer-branding
# ============================================
PKG="${PROJECT_ROOT}/packaging/nubifer-branding"

# os-release and system identity (use brand.conf values)
BNAME=$(grep 'BRAND_NAME=' "$PROJECT_ROOT/brand/brand.conf" | cut -d'"' -f2)
BVER=$(grep 'BRAND_VERSION=' "$PROJECT_ROOT/brand/brand.conf" | cut -d'"' -f2)
BCODE=$(grep 'BRAND_CODENAME=' "$PROJECT_ROOT/brand/brand.conf" | cut -d'"' -f2)
BSITE=$(grep 'BRAND_WEBSITE=' "$PROJECT_ROOT/brand/brand.conf" | cut -d'"' -f2)
BTAG=$(grep 'BRAND_TAGLINE=' "$PROJECT_ROOT/brand/brand.conf" | cut -d'"' -f2)
BCODE_LC=$(echo "$BCODE" | tr '[:upper:]' '[:lower:]')

# Store branding values for postinst to generate /etc files
# (os-release, lsb-release, issue, issue.net, motd conflict with base-files
# so we write them in postinst instead of shipping them in the package)
mkdir -p "$PKG/etc/nubiferos"
cat > "$PKG/etc/nubiferos/branding.conf" << BRANDEOF
BRAND_NAME="${BNAME}"
BRAND_VERSION="${BVER}"
BRAND_CODENAME="${BCODE}"
BRAND_CODENAME_LC="${BCODE_LC}"
BRAND_WEBSITE="${BSITE}"
BRAND_TAGLINE="${BTAG}"
BRANDEOF

# Wallpapers
mkdir -p "$PKG/usr/share/backgrounds/nubiferos"
if [ -d "$PROJECT_ROOT/brand/wallpapers/nubifer_dark" ]; then
    cp "$PROJECT_ROOT/brand/wallpapers/nubifer_dark/"*.png "$PKG/usr/share/backgrounds/nubiferos/" 2>/dev/null || true
fi
for wp in default aws azure gcp oracle; do
    [ -f "$PROJECT_ROOT/brand/wallpapers/${wp}.svg" ] && \
        cp "$PROJECT_ROOT/brand/wallpapers/${wp}.svg" "$PKG/usr/share/backgrounds/nubiferos/"
done
if [ -d "$PROJECT_ROOT/brand/wallpapers/png" ]; then
    cp "$PROJECT_ROOT/brand/wallpapers/png/"*.png "$PKG/usr/share/backgrounds/nubiferos/" 2>/dev/null || true
fi

# Icons
mkdir -p "$PKG/usr/share/pixmaps/nubiferos"
for size in 32 64 128 256 512; do
    if [ -f "$PROJECT_ROOT/brand/icons/logo-${size}.png" ]; then
        cp "$PROJECT_ROOT/brand/icons/logo-${size}.png" "$PKG/usr/share/pixmaps/nubiferos/"
        mkdir -p "$PKG/usr/share/icons/hicolor/${size}x${size}/apps"
        cp "$PROJECT_ROOT/brand/icons/logo-${size}.png" "$PKG/usr/share/icons/hicolor/${size}x${size}/apps/nubiferos.png"
    fi
done
[ -f "$PROJECT_ROOT/brand/logo.svg" ] && {
    cp "$PROJECT_ROOT/brand/logo.svg" "$PKG/usr/share/pixmaps/nubiferos/"
    mkdir -p "$PKG/usr/share/icons/hicolor/scalable/apps"
    cp "$PROJECT_ROOT/brand/logo.svg" "$PKG/usr/share/icons/hicolor/scalable/apps/nubiferos.svg"
}

# GDM branding
mkdir -p "$PKG/usr/share/gdm/greeter/images"
[ -f "$PROJECT_ROOT/brand/icons/logo-128.png" ] && \
    cp "$PROJECT_ROOT/brand/icons/logo-128.png" "$PKG/usr/share/gdm/greeter/images/logo.png"

mkdir -p "$PKG/etc/gdm3"
cat > "$PKG/etc/gdm3/greeter.dconf-defaults" << 'EOF'
# NubiferOS GDM Configuration
[org/gnome/login-screen]
logo='/usr/share/pixmaps/nubiferos/logo-128.png'
disable-user-list=false
banner-message-enable=false

[org/gnome/desktop/interface]
cursor-theme='Adwaita'
icon-theme='Adwaita'
EOF

# User face icon
mkdir -p "$PKG/etc/skel/.face.d"
[ -f "$PROJECT_ROOT/brand/icons/logo-256.png" ] && \
    cp "$PROJECT_ROOT/brand/icons/logo-256.png" "$PKG/etc/skel/.face"

# dconf settings (wallpaper, workspaces, extensions)
mkdir -p "$PKG/etc/dconf/db/local.d"
mkdir -p "$PKG/etc/dconf/db/local.d/locks"
mkdir -p "$PKG/etc/dconf/db/gdm.d"
mkdir -p "$PKG/etc/dconf/profile"

cat > "$PKG/etc/dconf/profile/user" << 'EOF'
user-db:user
system-db:local
EOF

cat > "$PKG/etc/dconf/profile/gdm" << 'EOF'
user-db:user
system-db:gdm
file-db:/usr/share/gdm/greeter-dconf-defaults
EOF

cat > "$PKG/etc/dconf/db/local.d/01-nubiferos-wallpaper" << 'EOF'
[org/gnome/desktop/background]
picture-uri='file:///usr/share/backgrounds/nubiferos/cyan_black_original_4K.png'
picture-uri-dark='file:///usr/share/backgrounds/nubiferos/cyan_black_original_4K.png'
picture-options='zoom'
primary-color='#000000'
secondary-color='#00ffff'

[org/gnome/desktop/screensaver]
picture-uri='file:///usr/share/backgrounds/nubiferos/cyan_black_original_4K.png'
primary-color='#000000'
secondary-color='#00ffff'

[org/gnome/desktop/wm/preferences]
button-layout='appmenu:minimize,maximize,close'

[org/gnome/shell]
enabled-extensions=['nubiferos-context@nubiferos.org', 'ding@rastersoft.com']
favorite-apps=['firefox-esr.desktop', 'org.gnome.Terminal.desktop', 'org.gnome.Nautilus.desktop', 'nubifer-dashboard.desktop', 'nubifer-audit-viewer.desktop', 'nubifer-software.desktop', 'ai.nubiferos.nubiferai.desktop']
EOF

cat > "$PKG/etc/dconf/db/local.d/02-nubiferos-workspaces" << 'EOF'
[org/gnome/desktop/wm/preferences]
num-workspaces=1

[org/gnome/mutter]
dynamic-workspaces=false

[org/gnome/shell/app-switcher]
current-workspace-only=true
EOF

cat > "$PKG/etc/dconf/db/local.d/locks/01-nubiferos-workspace-locks" << 'EOF'
/org/gnome/mutter/dynamic-workspaces
EOF

cat > "$PKG/etc/dconf/db/gdm.d/01-nubiferos-branding" << 'EOF'
[org/gnome/login-screen]
logo='/usr/share/pixmaps/nubiferos/logo-128.png'
banner-message-enable=false

[org/gnome/desktop/background]
picture-uri='file:///usr/share/backgrounds/nubiferos/cyan_black_original_4K.png'
picture-options='zoom'
primary-color='#000000'

[org/gnome/desktop/screensaver]
picture-uri='file:///usr/share/backgrounds/nubiferos/cyan_black_original_4K.png'
EOF

# GNOME wallpaper selection XML
mkdir -p "$PKG/usr/share/gnome-background-properties"
cp "$PROJECT_ROOT/build/install-branding-assets.sh" /dev/null 2>&1 || true
# Generate the XML inline (same content as install-branding-assets.sh)
cat > "$PKG/usr/share/gnome-background-properties/nubiferos.xml" << 'WPXML'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE wallpapers SYSTEM "gnome-wp-list.dtd">
<wallpapers>
  <wallpaper deleted="false">
    <name>NubiferOS Cyan (Default)</name>
    <filename>/usr/share/backgrounds/nubiferos/cyan_black_original_4K.png</filename>
    <options>zoom</options>
    <shade_type>solid</shade_type>
    <pcolor>#000000</pcolor>
    <scolor>#00ffff</scolor>
  </wallpaper>
  <wallpaper deleted="false">
    <name>NubiferOS Green</name>
    <filename>/usr/share/backgrounds/nubiferos/green_black_original_4K.png</filename>
    <options>zoom</options>
  </wallpaper>
  <wallpaper deleted="false">
    <name>NubiferOS Lime</name>
    <filename>/usr/share/backgrounds/nubiferos/lime_black_original_4K.png</filename>
    <options>zoom</options>
  </wallpaper>
  <wallpaper deleted="false">
    <name>NubiferOS Magenta</name>
    <filename>/usr/share/backgrounds/nubiferos/magenta_black_original_4K.png</filename>
    <options>zoom</options>
  </wallpaper>
  <wallpaper deleted="false">
    <name>NubiferOS Orange</name>
    <filename>/usr/share/backgrounds/nubiferos/orange_black_original_4K.png</filename>
    <options>zoom</options>
  </wallpaper>
  <wallpaper deleted="false">
    <name>NubiferOS Pink</name>
    <filename>/usr/share/backgrounds/nubiferos/pink_black_original_4K.png</filename>
    <options>zoom</options>
  </wallpaper>
  <wallpaper deleted="false">
    <name>NubiferOS Purple</name>
    <filename>/usr/share/backgrounds/nubiferos/purple_black_original_4K.png</filename>
    <options>zoom</options>
  </wallpaper>
  <wallpaper deleted="false">
    <name>NubiferOS Red</name>
    <filename>/usr/share/backgrounds/nubiferos/red_black_original_4K.png</filename>
    <options>zoom</options>
  </wallpaper>
  <wallpaper deleted="false">
    <name>NubiferOS White</name>
    <filename>/usr/share/backgrounds/nubiferos/white_black_original_4K.png</filename>
    <options>zoom</options>
  </wallpaper>
  <wallpaper deleted="false">
    <name>NubiferOS Yellow</name>
    <filename>/usr/share/backgrounds/nubiferos/yellow_black_original_4K.png</filename>
    <options>zoom</options>
  </wallpaper>
  <wallpaper deleted="false">
    <name>NubiferOS AWS Theme</name>
    <filename>/usr/share/backgrounds/nubiferos/aws.svg</filename>
    <options>zoom</options>
  </wallpaper>
  <wallpaper deleted="false">
    <name>NubiferOS Azure Theme</name>
    <filename>/usr/share/backgrounds/nubiferos/azure.svg</filename>
    <options>zoom</options>
  </wallpaper>
  <wallpaper deleted="false">
    <name>NubiferOS GCP Theme</name>
    <filename>/usr/share/backgrounds/nubiferos/gcp.svg</filename>
    <options>zoom</options>
  </wallpaper>
  <wallpaper deleted="false">
    <name>NubiferOS Oracle Theme</name>
    <filename>/usr/share/backgrounds/nubiferos/oracle.svg</filename>
    <options>zoom</options>
  </wallpaper>
</wallpapers>
WPXML

# GNOME Shell context indicator extension
EXTENSION_UUID="nubiferos-context@nubiferos.org"
EXTENSION_DIR="$PKG/usr/share/gnome-shell/extensions/${EXTENSION_UUID}"
mkdir -p "$EXTENSION_DIR"
if [ -d "$PROJECT_ROOT/components/context-indicator/gnome-extension" ]; then
    cp "$PROJECT_ROOT/components/context-indicator/gnome-extension/extension.js" "$EXTENSION_DIR/"
    cp "$PROJECT_ROOT/components/context-indicator/gnome-extension/metadata.json" "$EXTENSION_DIR/"
    cp "$PROJECT_ROOT/components/context-indicator/gnome-extension/stylesheet.css" "$EXTENSION_DIR/"
    # Session-state display module (Phase 2 task 5.2); extension.js degrades
    # gracefully without it, but the deb must ship it for the feature to work
    cp "$PROJECT_ROOT/components/context-indicator/gnome-extension/sessionState.js" "$EXTENSION_DIR/"
fi

# Terminal prompt integration
mkdir -p "$PKG/etc/profile.d"
if [ -f "$PROJECT_ROOT/components/context-indicator/nubiferos-prompt.sh" ]; then
    cp "$PROJECT_ROOT/components/context-indicator/nubiferos-prompt.sh" "$PKG/etc/profile.d/"
    chmod +x "$PKG/etc/profile.d/nubiferos-prompt.sh"
fi

# Plymouth theme
PLYMOUTH_DIR="$PKG/usr/share/plymouth/themes/nubiferos"
mkdir -p "$PLYMOUTH_DIR"
if [ -f "$PROJECT_ROOT/branding/plymouth/nubiferos/nubiferos.plymouth" ]; then
    cp "$PROJECT_ROOT/branding/plymouth/nubiferos/nubiferos.plymouth" "$PLYMOUTH_DIR/"
    cp "$PROJECT_ROOT/branding/plymouth/nubiferos/nubiferos.script" "$PLYMOUTH_DIR/"
fi
if [ -f "$PROJECT_ROOT/installer/calamares/branding/nubiferos/logo.png" ]; then
    cp "$PROJECT_ROOT/installer/calamares/branding/nubiferos/logo.png" "$PLYMOUTH_DIR/"
fi

build_package "nubifer-branding"

# ============================================
# 10. nubifer-ai
# ============================================
NUBIFERAI_REPO="https://github.com/nubiferos/nubiferai.git"
NUBIFERAI_BRANCH="trunk"
NUBIFERAI_CLONE_DIR="${OUTPUT_DIR}/build/_nubiferai-src"

# Clone NubiferAI source (needed for package contents)
if git clone --branch "$NUBIFERAI_BRANCH" --depth 1 "$NUBIFERAI_REPO" "$NUBIFERAI_CLONE_DIR" 2>/dev/null; then
    PKG="${PROJECT_ROOT}/packaging/nubifer-ai"

    # Ship the source packages for venv install in postinst
    mkdir -p "$PKG/opt/nubiferos/addons/nubiferai/packages"
    cp -r "$NUBIFERAI_CLONE_DIR/packages/nubiferai-core" "$PKG/opt/nubiferos/addons/nubiferai/packages/"
    cp -r "$NUBIFERAI_CLONE_DIR/packages/nubiferai-cli" "$PKG/opt/nubiferos/addons/nubiferai/packages/"
    cp -r "$NUBIFERAI_CLONE_DIR/packages/nubiferai-gtk" "$PKG/opt/nubiferos/addons/nubiferai/packages/" 2>/dev/null || true
    cp -r "$NUBIFERAI_CLONE_DIR/packages/nubiferai-dbus" "$PKG/opt/nubiferos/addons/nubiferai/packages/" 2>/dev/null || true

    # Ship bundled seeds
    if [ -d "$NUBIFERAI_CLONE_DIR/seeds" ]; then
        mkdir -p "$PKG/etc/nubiferai/seeds"
        cp "$NUBIFERAI_CLONE_DIR/seeds/"*.toml "$PKG/etc/nubiferai/seeds/" 2>/dev/null || true
    fi

    # Desktop entry — uses GTK if available, falls back to CLI in terminal
    mkdir -p "$PKG/usr/share/applications"
    cat > "$PKG/usr/share/applications/ai.nubiferos.nubiferai.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=NubiferAI
Comment=AI-native cloud operations assistant
Exec=sh -c 'if command -v nubiferai-gtk >/dev/null 2>&1; then nubiferai-gtk; else gnome-terminal -- bash -c "nubiferai front; exec bash"; fi'
Icon=weather-overcast-symbolic
Terminal=false
Categories=Development;Utility;
Keywords=ai;cloud;nubifer;assistant;
EOF

    build_package "nubifer-ai"

    # Cleanup clone
    rm -rf "$NUBIFERAI_CLONE_DIR"
else
    echo ""
    echo "--- Skipping nubifer-ai (could not clone $NUBIFERAI_REPO) ---"
fi

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
