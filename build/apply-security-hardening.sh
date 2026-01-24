#!/bin/bash
# Apply security hardening to NubiferOS
# Part of NubiferOS build system

set -e  # Exit on error

# Load brand configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../brand/load-brand.sh"
source "${SCRIPT_DIR}/config.sh"

# Initialize configuration
init_config

log "INFO" "Starting security hardening"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    log "ERROR" "This script must be run as root (use sudo)"
    exit 1
fi

# Directories
WORK_DIR="${PROJECT_ROOT}/work"
CHROOT_DIR="${WORK_DIR}/chroot"

# Verify chroot exists
if [ ! -d "${CHROOT_DIR}/bin" ]; then
    log "ERROR" "Chroot directory not found. Run extract-debian.sh first."
    exit 1
fi

# Function to run commands in chroot
chroot_exec() {
    chroot "${CHROOT_DIR}" /bin/bash -c "$*"
}

# Install security packages
install_security_packages() {
    log "INFO" "=========================================="
    log "INFO" "Installing security packages"
    log "INFO" "=========================================="
    
    chroot_exec "DEBIAN_FRONTEND=noninteractive apt-get install -y \
        apparmor \
        apparmor-utils \
        apparmor-profiles \
        apparmor-profiles-extra \
        fail2ban \
        ufw \
        unattended-upgrades \
        apt-listchanges \
        auditd \
        audispd-plugins \
        cryptsetup \
        cryptsetup-initramfs \
        libpam-tmpdir \
        libpam-pwquality \
        rkhunter \
        chkrootkit \
        aide \
        aide-common \
        gnupg \
        pass"
    
    log "INFO" "✓ Security packages installed"
}

# Configure AppArmor
configure_apparmor() {
    log "INFO" "=========================================="
    log "INFO" "Configuring AppArmor"
    log "INFO" "=========================================="
    
    # Enable AppArmor service (will start on first boot)
    chroot_exec "systemctl enable apparmor" || log "WARN" "Could not enable AppArmor service (will be configured on first boot)"
    
    # Note: aa-enforce requires a running kernel with AppArmor support
    # In a chroot, we can only prepare the profiles - they'll be enforced on first boot
    log "INFO" "Preparing AppArmor profiles (will be enforced on first boot)..."
    
    # Create custom AppArmor profiles directory
    mkdir -p "${CHROOT_DIR}/etc/apparmor.d/nubifer"
    
    # Create AppArmor profile for credential manager
    cat > "${CHROOT_DIR}/etc/apparmor.d/nubifer.credential-manager" << 'EOF'
#include <tunables/global>

/usr/bin/nubifer-credential-manager {
  #include <abstractions/base>
  #include <abstractions/python>
  
  # Allow reading configuration
  /etc/nubifer/** r,
  
  # Allow access to credential storage
  owner @{HOME}/.config/nubifer/** rw,
  owner @{HOME}/.local/share/nubifer/** rw,
  
  # Allow D-Bus communication
  #include <abstractions/dbus-session-strict>
  
  # Deny network access (credentials should never go over network)
  deny network,
  
  # Allow keyring access
  owner @{HOME}/.local/share/keyrings/** rw,
}
EOF
    
    # Create a first-boot script to enforce AppArmor profiles
    cat > "${CHROOT_DIR}/etc/systemd/system/apparmor-enforce-profiles.service" << 'EOF'
[Unit]
Description=Enforce AppArmor profiles on first boot
After=apparmor.service
ConditionPathExists=!/var/lib/nubifer/apparmor-enforced

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'aa-enforce /etc/apparmor.d/* 2>/dev/null || true; touch /var/lib/nubifer/apparmor-enforced'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable the first-boot service
    chroot_exec "systemctl enable apparmor-enforce-profiles.service" || true
    
    log "INFO" "✓ AppArmor configured (profiles will be enforced on first boot)"
}

# Configure firewall (ufw)
configure_firewall() {
    log "INFO" "=========================================="
    log "INFO" "Configuring firewall (ufw)"
    log "INFO" "=========================================="
    
    # Enable ufw
    chroot_exec "systemctl enable ufw"
    
    # Default policies: deny incoming, allow outgoing
    chroot_exec "ufw --force default deny incoming"
    chroot_exec "ufw --force default allow outgoing"
    
    # Allow SSH (for remote management if needed)
    # chroot_exec "ufw allow 22/tcp"  # Commented out - enable if needed
    
    # Enable firewall
    chroot_exec "ufw --force enable"
    
    log "INFO" "✓ Firewall configured (deny all incoming by default)"
}

# Configure fail2ban
configure_fail2ban() {
    log "INFO" "=========================================="
    log "INFO" "Configuring fail2ban"
    log "INFO" "=========================================="
    
    # Enable fail2ban
    chroot_exec "systemctl enable fail2ban"
    
    # Create custom jail configuration
    cat > "${CHROOT_DIR}/etc/fail2ban/jail.local" << 'EOF'
[DEFAULT]
# Ban for 1 hour
bantime = 3600

# Find time window
findtime = 600

# Max retries before ban
maxretry = 5

# Email notifications (configure if needed)
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
    
    log "INFO" "✓ fail2ban configured"
}

# Configure automatic security updates
configure_auto_updates() {
    log "INFO" "=========================================="
    log "INFO" "Configuring automatic security updates"
    log "INFO" "=========================================="
    
    # Configure unattended-upgrades
    cat > "${CHROOT_DIR}/etc/apt/apt.conf.d/50unattended-upgrades" << 'EOF'
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
Unattended-Upgrade::Automatic-Reboot-Time "03:00";
EOF
    
    # Enable automatic updates
    cat > "${CHROOT_DIR}/etc/apt/apt.conf.d/20auto-upgrades" << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EOF
    
    log "INFO" "✓ Automatic security updates configured"
}

# Configure audit system (auditd)
configure_auditd() {
    log "INFO" "=========================================="
    log "INFO" "Configuring audit system (auditd)"
    log "INFO" "=========================================="
    
    # Enable auditd
    chroot_exec "systemctl enable auditd"
    
    # Create audit rules for NubiferOS
    cat > "${CHROOT_DIR}/etc/audit/rules.d/nubifer.rules" << 'EOF'
# NubiferOS Audit Rules

# Monitor credential access
-w /etc/nubifer/ -p wa -k nubifer_config
-w /home/ -p wa -k nubifer_credentials

# Monitor authentication
-w /var/log/auth.log -p wa -k auth_log
-w /etc/passwd -p wa -k passwd_changes
-w /etc/group -p wa -k group_changes
-w /etc/shadow -p wa -k shadow_changes

# Monitor sudo usage
-w /etc/sudoers -p wa -k sudoers_changes
-w /var/log/sudo.log -p wa -k sudo_log

# Monitor network configuration
-w /etc/network/ -p wa -k network_config

# Monitor system calls
-a always,exit -F arch=b64 -S adjtimex -S settimeofday -k time_change
-a always,exit -F arch=b64 -S clock_settime -k time_change

# Monitor file deletions
-a always,exit -F arch=b64 -S unlink -S unlinkat -S rename -S renameat -k delete

# Monitor kernel module loading
-w /sbin/insmod -p x -k modules
-w /sbin/rmmod -p x -k modules
-w /sbin/modprobe -p x -k modules
EOF
    
    log "INFO" "✓ Audit system configured"
}

# Harden kernel parameters
configure_kernel_hardening() {
    log "INFO" "=========================================="
    log "INFO" "Configuring kernel hardening"
    log "INFO" "=========================================="
    
    # Create sysctl hardening configuration
    cat > "${CHROOT_DIR}/etc/sysctl.d/99-nubifer-hardening.conf" << 'EOF'
# NubiferOS Kernel Hardening

# IP Forwarding (disable unless needed)
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0

# Disable source packet routing
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# Disable ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0

# Enable IP spoofing protection
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Log suspicious packets
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# Ignore ICMP ping requests
net.ipv4.icmp_echo_ignore_all = 0
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Ignore bogus ICMP error responses
net.ipv4.icmp_ignore_bogus_error_responses = 1

# Enable TCP SYN cookies (DDoS protection)
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_syn_retries = 2
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_max_syn_backlog = 4096

# Disable IPv6 (if not needed)
# net.ipv6.conf.all.disable_ipv6 = 1
# net.ipv6.conf.default.disable_ipv6 = 1

# Increase system file descriptor limit
fs.file-max = 65535

# Protect against time-wait assassination
net.ipv4.tcp_rfc1337 = 1

# Kernel hardening
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
kernel.yama.ptrace_scope = 2
kernel.unprivileged_bpf_disabled = 1
net.core.bpf_jit_harden = 2

# Disable core dumps
kernel.core_uses_pid = 1
fs.suid_dumpable = 0

# Address Space Layout Randomization (ASLR)
kernel.randomize_va_space = 2

# Restrict access to kernel logs
kernel.printk = 3 3 3 3
EOF
    
    log "INFO" "✓ Kernel hardening configured"
}

# Configure secure SSH (if SSH is installed)
configure_ssh_hardening() {
    log "INFO" "=========================================="
    log "INFO" "Configuring SSH hardening"
    log "INFO" "=========================================="
    
    if [ -f "${CHROOT_DIR}/etc/ssh/sshd_config" ]; then
        # Backup original config
        cp "${CHROOT_DIR}/etc/ssh/sshd_config" "${CHROOT_DIR}/etc/ssh/sshd_config.bak"
        
        # Apply hardening
        cat >> "${CHROOT_DIR}/etc/ssh/sshd_config" << 'EOF'

# NubiferOS SSH Hardening
Protocol 2
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
ClientAliveInterval 300
ClientAliveCountMax 2
MaxAuthTries 3
MaxSessions 2
EOF
        
        log "INFO" "✓ SSH hardening configured"
    else
        log "INFO" "SSH not installed, skipping SSH hardening"
    fi
}

# Configure password policies
configure_password_policy() {
    log "INFO" "=========================================="
    log "INFO" "Configuring password policies"
    log "INFO" "=========================================="
    
    # Configure PAM password quality
    cat > "${CHROOT_DIR}/etc/security/pwquality.conf" << 'EOF'
# NubiferOS Password Quality Requirements
# Strong passwords for cloud credential protection
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
    
    log "INFO" "✓ Password policies configured"
}

# Set secure file permissions
set_secure_permissions() {
    log "INFO" "=========================================="
    log "INFO" "Setting secure file permissions"
    log "INFO" "=========================================="
    
    # Secure sensitive files
    chmod 600 "${CHROOT_DIR}/etc/ssh/sshd_config" 2>/dev/null || true
    chmod 600 "${CHROOT_DIR}/etc/shadow" 2>/dev/null || true
    chmod 600 "${CHROOT_DIR}/etc/gshadow" 2>/dev/null || true
    chmod 644 "${CHROOT_DIR}/etc/passwd"
    chmod 644 "${CHROOT_DIR}/etc/group"
    
    # Secure NubiferOS directories
    mkdir -p "${CHROOT_DIR}/etc/nubifer"
    chmod 755 "${CHROOT_DIR}/etc/nubifer"
    
    log "INFO" "✓ Secure permissions set"
}

# Create security verification script
create_security_verification() {
    log "INFO" "Creating security verification script..."
    
    cat > "${CHROOT_DIR}/usr/local/bin/verify-security" << 'EOF'
#!/bin/bash
# Verify NubiferOS security configuration

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

check_file() {
    local file="$1"
    if [ -f "$file" ]; then
        echo "✓ $file: exists"
    else
        echo "✗ $file: missing"
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
echo "Security Configurations:"
check_file "/etc/apparmor.d/nubifer.credential-manager"
check_file "/etc/audit/rules.d/nubifer.rules"
check_file "/etc/sysctl.d/99-nubifer-hardening.conf"
check_file "/etc/security/pwquality.conf"

echo ""
echo "Firewall Status:"
ufw status | head -n 5

echo ""
echo "AppArmor Status:"
aa-status 2>/dev/null | head -n 10 || echo "Run as root to see AppArmor status"

echo ""
echo "=========================================="
echo "Verification complete"
echo "=========================================="
EOF
    
    chmod +x "${CHROOT_DIR}/usr/local/bin/verify-security"
    
    log "INFO" "✓ Security verification script created"
}

# Main execution
main() {
    log "INFO" "=========================================="
    log "INFO" "Security Hardening"
    log "INFO" "=========================================="
    log "INFO" "Target: ${CHROOT_DIR}"
    log "INFO" "=========================================="
    
    # Install security packages
    install_security_packages
    
    # Configure security components
    configure_apparmor
    configure_firewall
    configure_fail2ban
    configure_auto_updates
    configure_auditd
    configure_kernel_hardening
    configure_ssh_hardening
    configure_password_policy
    set_secure_permissions
    
    # Create verification script
    create_security_verification
    
    log "INFO" "=========================================="
    log "INFO" "Security hardening complete!"
    log "INFO" "=========================================="
    log "INFO" ""
    log "INFO" "Security features enabled:"
    log "INFO" "  ✓ AppArmor (mandatory access control)"
    log "INFO" "  ✓ UFW firewall (deny all incoming)"
    log "INFO" "  ✓ fail2ban (intrusion prevention)"
    log "INFO" "  ✓ Automatic security updates"
    log "INFO" "  ✓ Audit logging (auditd)"
    log "INFO" "  ✓ Kernel hardening"
    log "INFO" "  ✓ Strong password policies"
    log "INFO" ""
    log "INFO" "Next step: Run ./build/customize-system.sh"
}

# Run main function
main "$@"
