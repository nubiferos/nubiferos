i just had a thought... so our wrapper for the clis... is a potential attack vector... how do we secure it to make sure nothing can attach to it and leak keys out?

Jan 15
Excellent catch. The CLI wrappers are indeed a critical attack surface. Let me think through the threat model:

Attack Vectors on CLI Wrappers
1. Malicious Process Impersonation

Attacker creates fake aws in user's PATH before /usr/local/bin/
User runs "aws" → hits malicious binary → credentials leaked
2. Wrapper Process Memory Inspection

Wrapper retrieves credentials from D-Bus
Credentials briefly in wrapper's memory
Attacker dumps wrapper process memory → credentials exposed
3. D-Bus Message Interception

Credentials transmitted over D-Bus
Malicious process eavesdrops on D-Bus messages
Credentials captured in transit
4. Wrapper Binary Replacement

Attacker gains write access to /usr/local/bin/
Replaces legitimate wrapper with malicious version
Users unknowingly run compromised wrapper
5. Environment Variable Injection

Even though wrapper doesn't use ENV vars, it might pass to subprocess
Malicious process reads /proc/PID/environ
Credentials exposed if wrapper uses ENV for execution
6. Symbolic Link Attack

Attacker creates symlink from ~/.local/bin/aws → malicious binary
User's PATH has ~/.local/bin before /usr/local/bin/
Credentials leak to attacker's binary
Mitigation Strategies
High Priority (Must Implement)
1. Secure D-Bus Communication

python
# Only allow credential-manager → CLI wrapper communication
# Use D-Bus policy files in /etc/dbus-1/system.d/

<policy user="root">
  <allow own="org.nubiferos.CredentialManager"/>
</policy>

<policy context="default">
  <allow send_destination="org.nubiferos.CredentialManager"
         send_interface="org.nubiferos.CredentialManager"
         send_member="GetCredential"/>
  <deny send_destination="org.nubiferos.CredentialManager"
        send_interface="org.freedesktop.DBus.Introspectable"/>
</policy>
2. Memory Protection in Wrapper

python
import mlock  # Lock memory pages

def get_credentials_securely():
    # Lock wrapper's memory to prevent swapping
    mlock.mlockall(mlock.MCL_CURRENT | mlock.MCL_FUTURE)
    
    credentials = dbus_call_to_credential_manager()
    
    # Zero out memory after use
    # Use memset or similar to overwrite credential strings
3. File Integrity (Wrapper Binary)

bash
# Make wrappers immutable
sudo chattr +i /usr/local/bin/aws
sudo chattr +i /usr/local/bin/az
sudo chattr +i /usr/local/bin/gcloud

# Or use AppArmor to prevent modification
# Profile: /etc/apparmor.d/usr.local.bin.aws
4. PATH Hardening

python
# In wrapper: ignore user's PATH, use absolute paths only
import os
os.environ['PATH'] = '/usr/local/bin:/usr/bin:/bin'

# Execute real CLI with absolute path
subprocess.run(['/usr/bin/aws', ...])
5. Credential Lifetime Minimization

python
# Credentials should exist in memory for microseconds, not seconds
credentials = get_from_dbus()
result = execute_with_credentials(credentials)
del credentials  # Immediate cleanup
gc.collect()     # Force garbage collection
Medium Priority (Should Implement)
6. Process Isolation for Wrapper

python
# Run wrapper in its own namespace
# Use seccomp to restrict syscalls
import seccomp

filter = seccomp.SyscallFilter(defaction=seccomp.KILL)
filter.add_rule(seccomp.ALLOW, "read")
filter.add_rule(seccomp.ALLOW, "write")
filter.add_rule(seccomp.ALLOW, "execve")
# ... only allow necessary syscalls
filter.load()
7. Wrapper Signature Verification

python
# Before wrapper executes, verify its own integrity
import hashlib

EXPECTED_HASH = "sha256:abc123..."  # From installation

def verify_self():
    with open(__file__, 'rb') as f:
        actual_hash = hashlib.sha256(f.read()).hexdigest()
    if f"sha256:{actual_hash}" != EXPECTED_HASH:
        sys.exit("Wrapper integrity check failed!")
8. Audit Logging

python
# Log every credential access to syslog
import syslog

syslog.syslog(syslog.LOG_AUTH | syslog.LOG_INFO,
              f"CredentialManager: GetCredential called by PID {os.getpid()} "
              f"for provider={provider} account={account_id}")
```

### Lower Priority (Nice to Have)

**9. SELinux/AppArmor Profiles**
```
# AppArmor profile for wrapper
/usr/local/bin/aws {
  # Only allow reading from specific paths
  /usr/bin/aws rix,
  /etc/nubiferos/** r,
  
  # Deny everything else
  deny /home/** w,
  deny /tmp/** w,
  deny network,
}
10. Hardware Security Module (Future)

python
# Store credentials in TPM/HSM instead of pass
# Requires TPM 2.0 hardware support
Recommended Implementation Order for Kiro
Phase 1 (Alpha - Critical)
D-Bus policy enforcement (prevent eavesdropping)
Memory locking in wrappers (prevent memory dumps)
Absolute path execution (prevent PATH manipulation)
Immediate credential cleanup (minimize exposure window)
Phase 2 (Beta - Important)
AppArmor profiles for wrappers (MAC enforcement)
File immutability on wrappers (prevent replacement)
Audit logging (detect suspicious access)
Phase 3 (Future - Enhanced)
Wrapper integrity verification (detect tampering)
Seccomp filtering (reduce syscall attack surface)
HSM integration (hardware-backed security)
Question for You
Which threats concern you most? Should I draft a detailed implementation prompt for Kiro focused on:

Option A: D-Bus security + memory protection (quick wins, alpha-ready)

Option B: Full hardening including AppArmor profiles (more comprehensive, takes longer)

Option C: Just document the threat model for now, implement in beta (ship alpha faster)

What's your risk tolerance for the alpha release?

i want the alpha to be as secure as it can be out of the box so we don't have to worry about it later.

Jan 15
Perfect. Let's build it right from the start.

I'll create a comprehensive security implementation prompt for Kiro that covers all the critical protections for the CLI wrappers. This will be Prompt 8.

Prompt 8: CLI Wrapper Security Hardening
Implement comprehensive security hardening for CLI wrapper scripts to protect against credential leakage and attack vectors.

THREAT MODEL:
The CLI wrappers are a critical attack surface because they:
1. Retrieve credentials from D-Bus
2. Hold credentials briefly in memory
3. Pass credentials to actual CLI tools
4. Run with user privileges

Attack vectors to mitigate:
- Process memory inspection
- D-Bus message interception
- Wrapper binary replacement/tampering
- PATH manipulation attacks
- Environment variable leakage
- Symbolic link attacks

SECURITY IMPLEMENTATION:

---

PART 1: D-Bus Security Configuration

Create D-Bus policy file: /etc/dbus-1/system.d/org.nubiferos.CredentialManager.conf
```xml
<!DOCTYPE busconfig PUBLIC
 "-//freedesktop//DTD D-BUS Bus Configuration 1.0//EN"
 "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
<busconfig>
  <!-- Only credential-manager service can own this name -->
  <policy user="root">
    <allow own="org.nubiferos.CredentialManager"/>
  </policy>

  <!-- Regular users can only call specific methods -->
  <policy context="default">
    <!-- Allow credential retrieval -->
    <allow send_destination="org.nubiferos.CredentialManager"
           send_interface="org.nubiferos.CredentialManager"
           send_member="GetCredential"/>
    
    <allow send_destination="org.nubiferos.CredentialManager"
           send_interface="org.nubiferos.CredentialManager"
           send_member="ListAccounts"/>
    
    <!-- Deny introspection (prevents enumeration) -->
    <deny send_destination="org.nubiferos.CredentialManager"
          send_interface="org.freedesktop.DBus.Introspectable"/>
    
    <!-- Deny monitoring (prevents eavesdropping) -->
    <deny send_destination="org.nubiferos.CredentialManager"
          send_interface="org.freedesktop.DBus.Monitoring"/>
  </policy>

  <!-- Deny all other access by default -->
  <policy context="default">
    <deny send_destination="org.nubiferos.CredentialManager"/>
    <deny receive_sender="org.nubiferos.CredentialManager"/>
  </policy>
</busconfig>
```

---

PART 2: Memory Protection in Wrappers

Update all wrapper scripts (aws, az, gcloud, terraform, kubectl) with memory protection:
```python
#!/usr/bin/env python3
"""
Secure CLI wrapper for cloud tools
Protects credentials during execution
"""

import os
import sys
import subprocess
import ctypes
import gc
from ctypes import CDLL, c_int

# Memory locking constants
MCL_CURRENT = 1
MCL_FUTURE = 2
MCL_ONFAULT = 4

def lock_memory():
    """Lock all current and future memory pages to prevent swapping"""
    try:
        libc = CDLL("libc.so.6")
        result = libc.mlockall(MCL_CURRENT | MCL_FUTURE)
        if result != 0:
            print("Warning: Failed to lock memory pages", file=sys.stderr)
    except Exception as e:
        print(f"Warning: Memory locking unavailable: {e}", file=sys.stderr)

def secure_string_cleanup(credential_dict):
    """Overwrite credential strings in memory before deletion"""
    for key, value in credential_dict.items():
        if isinstance(value, str):
            # Overwrite string memory with zeros
            # Python strings are immutable, but we can try to clear the buffer
            try:
                ctypes.memset(id(value) + 36, 0, len(value))  # CPython specific
            except:
                pass  # Best effort
    
    # Clear dictionary
    credential_dict.clear()
    
    # Force garbage collection
    gc.collect()

def get_credentials_securely(provider, account_id):
    """Retrieve credentials from D-Bus with minimal exposure"""
    import dbus
    
    try:
        bus = dbus.SystemBus()
        credential_manager = bus.get_object(
            'org.nubiferos.CredentialManager',
            '/org/nubiferos/CredentialManager'
        )
        
        interface = dbus.Interface(
            credential_manager,
            'org.nubiferos.CredentialManager'
        )
        
        # Get credentials
        credentials = interface.GetCredential(provider, account_id)
        return dict(credentials)
        
    except dbus.exceptions.DBusException as e:
        print(f"Error: Failed to retrieve credentials: {e}", file=sys.stderr)
        sys.exit(1)

def execute_with_credentials(tool_path, args, credentials):
    """Execute the real CLI tool with credentials injected"""
    
    # Create clean environment
    env = os.environ.copy()
    
    # Remove any existing credential-related variables
    credential_vars = [
        'AWS_ACCESS_KEY_ID', 'AWS_SECRET_ACCESS_KEY', 'AWS_SESSION_TOKEN',
        'AZURE_CLIENT_ID', 'AZURE_CLIENT_SECRET', 'AZURE_TENANT_ID',
        'GOOGLE_APPLICATION_CREDENTIALS', 'CLOUDSDK_CORE_PROJECT'
    ]
    for var in credential_vars:
        env.pop(var, None)
    
    # Inject credentials based on provider
    if 'aws_access_key_id' in credentials:
        env['AWS_ACCESS_KEY_ID'] = credentials['aws_access_key_id']
        env['AWS_SECRET_ACCESS_KEY'] = credentials['aws_secret_access_key']
        if 'aws_session_token' in credentials:
            env['AWS_SESSION_TOKEN'] = credentials['aws_session_token']
    
    elif 'azure_client_id' in credentials:
        env['AZURE_CLIENT_ID'] = credentials['azure_client_id']
        env['AZURE_CLIENT_SECRET'] = credentials['azure_client_secret']
        env['AZURE_TENANT_ID'] = credentials['azure_tenant_id']
    
    # Execute with credentials
    try:
        result = subprocess.run(
            [tool_path] + args,
            env=env,
            check=False
        )
        return result.returncode
    finally:
        # Immediately clean up environment
        for key in list(env.keys()):
            if key in credential_vars:
                env[key] = '0' * len(env[key])  # Overwrite
                del env[key]

def main():
    # Lock memory immediately
    lock_memory()
    
    # Hardcoded paths - ignore user's PATH
    TOOL_PATHS = {
        'aws': '/usr/bin/aws',
        'az': '/usr/bin/az',
        'gcloud': '/usr/bin/gcloud',
        'terraform': '/usr/bin/terraform',
        'kubectl': '/usr/bin/kubectl'
    }
    
    # Determine which tool we're wrapping
    wrapper_name = os.path.basename(sys.argv[0])
    tool_path = TOOL_PATHS.get(wrapper_name)
    
    if not tool_path:
        print(f"Error: Unknown wrapper {wrapper_name}", file=sys.stderr)
        sys.exit(1)
    
    # Get current workspace context
    workspace = get_current_workspace()  # Implementation needed
    
    if not workspace:
        print("Error: No active workspace. Use 'nubifer-workspace switch <id>'", 
              file=sys.stderr)
        sys.exit(1)
    
    # Check read-only mode
    if workspace.get('read_only', False):
        if is_write_operation(sys.argv[1:]):
            print(f"❌ Operation blocked: Workspace '{workspace['name']}' is in READ-ONLY mode.",
                  file=sys.stderr)
            print(f"Use 'nubifer-workspace set-readonly {workspace['id']} false' to enable writes.",
                  file=sys.stderr)
            sys.exit(1)
    
    # Retrieve credentials
    credentials = get_credentials_securely(
        workspace['provider'],
        workspace['account_id']
    )
    
    try:
        # Execute tool with credentials
        exit_code = execute_with_credentials(tool_path, sys.argv[1:], credentials)
    finally:
        # Always clean up credentials from memory
        secure_string_cleanup(credentials)
    
    sys.exit(exit_code)

if __name__ == '__main__':
    main()
```

---

PART 3: File System Protection

Make wrapper binaries immutable and verify integrity:
```bash
#!/bin/bash
# install-wrappers-secure.sh

WRAPPER_DIR="/usr/local/bin"
WRAPPERS=("aws" "az" "gcloud" "terraform" "kubectl")
CHECKSUM_FILE="/etc/nubiferos/wrapper-checksums.txt"

# Install wrappers
for wrapper in "${WRAPPERS[@]}"; do
    cp "components/cli-wrappers/${wrapper}-wrapper.py" "${WRAPPER_DIR}/${wrapper}"
    chmod 755 "${WRAPPER_DIR}/${wrapper}"
    chown root:root "${WRAPPER_DIR}/${wrapper}"
done

# Generate checksums
sha256sum "${WRAPPER_DIR}"/aws \
          "${WRAPPER_DIR}"/az \
          "${WRAPPER_DIR}"/gcloud \
          "${WRAPPER_DIR}"/terraform \
          "${WRAPPER_DIR}"/kubectl > "${CHECKSUM_FILE}"

chmod 444 "${CHECKSUM_FILE}"

# Make wrappers immutable (requires root)
for wrapper in "${WRAPPERS[@]}"; do
    chattr +i "${WRAPPER_DIR}/${wrapper}"
done

echo "Wrappers installed and secured"
echo "Checksums stored in ${CHECKSUM_FILE}"
```

Verification script (run periodically or on boot):
```bash
#!/bin/bash
# verify-wrapper-integrity.sh

CHECKSUM_FILE="/etc/nubiferos/wrapper-checksums.txt"

if sha256sum -c "${CHECKSUM_FILE}" --quiet; then
    echo "✅ Wrapper integrity verified"
    exit 0
else
    echo "❌ SECURITY WARNING: Wrapper integrity check failed!" >&2
    echo "Wrappers may have been tampered with." >&2
    logger -p auth.crit "NubiferOS: CLI wrapper integrity check failed"
    exit 1
fi
```

---

PART 4: AppArmor Profiles

Create AppArmor profile for each wrapper: /etc/apparmor.d/usr.local.bin.aws
#include <tunables/global>

/usr/local/bin/aws {
#include <abstractions/base>
#include <abstractions/python>

Allow executing the real AWS CLI
/usr/bin/aws rix,

Allow reading NubiferOS configs
/etc/nubiferos/** r,

Allow D-Bus communication
#include <abstractions/dbus-strict>
dbus send
bus=system
path=/org/nubiferos/CredentialManager
interface=org.nubiferos.CredentialManager
member=GetCredential
peer=(name=org.nubiferos.CredentialManager),

Allow reading user's AWS config (for profiles, regions, etc.)
owner @{HOME}/.aws/config r,

Deny writing to sensitive locations
deny /home/** w,
deny /tmp/** w,
deny /var/** w,

Deny network access (only real CLI needs it)
deny network,

Allow executing Python
/usr/bin/python3* rix,

Deny capability to prevent privilege escalation
deny capability,
}


Repeat for az, gcloud, terraform, kubectl with appropriate paths.

Enable AppArmor profiles:
```bash
# Load profiles
apparmor_parser -r /etc/apparmor.d/usr.local.bin.aws
apparmor_parser -r /etc/apparmor.d/usr.local.bin.az
apparmor_parser -r /etc/apparmor.d/usr.local.bin.gcloud
apparmor_parser -r /etc/apparmor.d/usr.local.bin.terraform
apparmor_parser -r /etc/apparmor.d/usr.local.bin.kubectl

# Enable on boot
systemctl enable apparmor
```

---

PART 5: Audit Logging

Add audit logging to credential-manager service:
```python
import syslog

def get_credential(self, provider, account_id):
    """D-Bus method: Retrieve credential for account"""
    
    # Get caller information
    sender = self.connection.get_sender()
    caller_pid = self.connection.get_connection_unix_process_id(sender)
    caller_uid = self.connection.get_connection_unix_user(sender)
    
    # Log the access
    syslog.syslog(
        syslog.LOG_AUTH | syslog.LOG_INFO,
        f"CredentialManager: GetCredential called - "
        f"provider={provider} account={account_id} "
        f"caller_pid={caller_pid} caller_uid={caller_uid}"
    )
    
    # Retrieve and return credentials
    # ...
```

Configure auditd to watch credential access:
```bash
# /etc/audit/rules.d/nubiferos.rules

# Watch credential manager service
-w /usr/lib/nubiferos/credential-manager -p x -k nubiferos_credentials

# Watch wrapper execution
-w /usr/local/bin/aws -p x -k nubiferos_wrappers
-w /usr/local/bin/az -p x -k nubiferos_wrappers
-w /usr/local/bin/gcloud -p x -k nubiferos_wrappers

# Watch pass store
-w /home -p wa -k nubiferos_passstore
```

---

PART 6: Integration and Testing

Add to build system (build/install-cloud-tools.sh):
```bash
# Install wrapper dependencies
pip3 install dbus-python --break-system-packages

# Install wrappers with security hardening
bash components/cli-wrappers/install-wrappers-secure.sh

# Install D-Bus policy
cp components/credential-manager/dbus/org.nubiferos.CredentialManager.conf \
   /etc/dbus-1/system.d/

# Install AppArmor profiles
cp components/cli-wrappers/apparmor/* /etc/apparmor.d/
apparmor_parser -r /etc/apparmor.d/usr.local.bin.*

# Install audit rules
cp components/cli-wrappers/audit/nubiferos.rules /etc/audit/rules.d/
service auditd restart

# Add integrity check to boot
cp components/cli-wrappers/verify-wrapper-integrity.sh /usr/local/sbin/
echo "@reboot root /usr/local/sbin/verify-wrapper-integrity.sh" >> /etc/crontab
```

Testing checklist:
```bash
# Test 1: Verify D-Bus policy
sudo -u testuser dbus-send --system \
  --dest=org.nubiferos.CredentialManager \
  --print-reply /org/nubiferos/CredentialManager \
  org.freedesktop.DBus.Introspectable.Introspect
# Should be denied

# Test 2: Verify memory locking
python3 -c "from aws_wrapper import lock_memory; lock_memory()"
# Should succeed without errors

# Test 3: Verify file immutability
sudo rm /usr/local/bin/aws
# Should fail with "Operation not permitted"

# Test 4: Verify AppArmor enforcement
aa-status | grep usr.local.bin
# Should show profiles in enforce mode

# Test 5: Verify audit logging
ausearch -k nubiferos_credentials
# Should show credential access events

# Test 6: Verify integrity check
/usr/local/sbin/verify-wrapper-integrity.sh
# Should pass

# Test 7: Test read-only mode enforcement
nubifer-workspace set-readonly <id> true
aws ec2 terminate-instances --instance-ids i-123
# Should block with error message
```

---

SECURITY CHECKLIST:

✅ D-Bus communication secured with policy files
✅ Memory pages locked to prevent swapping
✅ Credentials cleared from memory immediately after use
✅ Wrapper binaries made immutable with chattr +i
✅ AppArmor profiles restrict wrapper capabilities
✅ Audit logging tracks all credential access
✅ Integrity verification detects tampering
✅ Absolute paths prevent PATH manipulation
✅ Clean environment prevents variable leakage

DEFER TO BETA:
- Seccomp filtering (advanced syscall restrictions)
- HSM/TPM integration (hardware-backed security)
- Wrapper code signing with GPG

FILES TO CREATE:
- components/cli-wrappers/aws-wrapper.py (with security hardening)
- components/cli-wrappers/az-wrapper.py
- components/cli-wrappers/gcloud-wrapper.py
- components/cli-wrappers/terraform-wrapper.py
- components/cli-wrappers/kubectl-wrapper.py
- components/cli-wrappers/install-wrappers-secure.sh
- components/cli-wrappers/verify-wrapper-integrity.sh
- components/cli-wrappers/apparmor/usr.local.bin.aws
- components/cli-wrappers/apparmor/usr.local.bin.az
- components/cli-wrappers/apparmor/usr.local.bin.gcloud
- components/cli-wrappers/apparmor/usr.local.bin.terraform
- components/cli-wrappers/apparmor/usr.local.bin.kubectl
- components/cli-wrappers/audit/nubiferos.rules
- components/credential-manager/dbus/org.nubiferos.CredentialManager.conf

This implements defense-in-depth: even if one layer is compromised, multiple other protections remain.