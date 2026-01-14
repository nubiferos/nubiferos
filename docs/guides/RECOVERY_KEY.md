## NubiferOS Recovery Key System

## Overview

NubiferOS includes a **physical USB recovery key** system for emergency access. This provides a secure, no-backdoor recovery mechanism that requires physical access.

### Key Principles

✅ **Physical Access Required** - No remote/network access possible  
✅ **No Backdoors** - Created during installation by the user  
✅ **Full System Access** - Can reset passwords, unlock drives  
✅ **Secure Storage** - Must be stored in safe/vault  
✅ **Multiple Copies** - Create backups for redundancy  

## When to Use Recovery Key

**Emergency Scenarios:**
- 🔐 Forgotten user password
- 🔒 Lost LUKS encryption passphrase
- 👤 Rogue employee locked out legitimate users
- 🚨 System locked due to failed login attempts
- 💾 Need emergency access to encrypted data

**NOT for:**
- ❌ Regular password resets (use normal methods)
- ❌ Convenience (defeats security purpose)
- ❌ Sharing access (each admin should have own account)

## Creating Recovery Key

### During Installation

The installer will prompt to create a recovery key:

```
┌─────────────────────────────────────────┐
│  Create Recovery Key?                   │
├─────────────────────────────────────────┤
│  A recovery key allows emergency access │
│  to the system with physical USB.       │
│                                         │
│  ⚠️  Physical access = full control     │
│                                         │
│  [ ] Create recovery key now            │
│  [ ] Skip (can create later)            │
│                                         │
│  Recommended: Create and store securely │
└─────────────────────────────────────────┘
```

### After Installation

Run the recovery key setup:

```bash
sudo nubifer-recovery-key-setup
```

### Setup Process

1. **Insert blank USB drive** (will be erased!)
2. **Run setup script**
3. **Select USB device** from list
4. **Confirm** (all data will be erased)
5. **Wait** for key generation
6. **Optionally** add to LUKS encrypted drives
7. **Remove USB** and store securely

## Recovery Key Contents

The USB drive contains:

```
NUBIFER_RECOVERY/
├── recovery.key          # Cryptographic key (4096 bytes)
├── recovery.sh           # Recovery script
├── RECOVERY_INFO.txt     # System information
└── README.txt            # Quick instructions
```

### recovery.key
- 4096-byte random key
- Base64 encoded
- Used for cryptographic operations
- Permissions: 400 (read-only by owner)

### recovery.sh
- Interactive recovery script
- Password reset
- Drive unlocking
- Emergency shell
- Log viewing

### RECOVERY_INFO.txt
- System hostname
- Creation date
- System UUID
- Usage instructions
- Emergency contacts

## Using Recovery Key

### Step 1: Boot System

Boot the NubiferOS system normally (or from live USB if needed).

### Step 2: Insert Recovery USB

Insert the recovery USB drive.

### Step 3: Run Recovery Command

```bash
sudo nubifer-recovery
```

The system will:
1. Detect recovery USB
2. Mount it
3. Verify recovery key
4. Present recovery menu

### Step 4: Select Recovery Option

```
========================================
NubiferOS Recovery Mode
========================================

Recovery Options:
  1) Reset user password
  2) Unlock encrypted drive
  3) Emergency shell access
  4) View system logs
  5) Exit

Select option (1-5):
```

### Option 1: Reset User Password

```bash
Select option: 1

Reset User Password
-------------------
Username: john
New password: ****************
Retype password: ****************
✓ Password reset for john
```

### Option 2: Unlock Encrypted Drive

```bash
Select option: 2

Unlock Encrypted Drive
----------------------
Available encrypted devices:
sda2  100G  crypt

Device (e.g., /dev/sda2): /dev/sda2
✓ Device unlocked as /dev/mapper/recovery_unlock
```

### Option 3: Emergency Shell

```bash
Select option: 3

Emergency Shell Access
----------------------
Type 'exit' to return

root@nubifer:~#
```

### Option 4: View System Logs

```bash
Select option: 4

System Logs
-----------
[Recent system logs displayed]
```

## Security Best Practices

### Storage

✅ **Do:**
- Store in physical safe or vault
- Keep in secure facility
- Use tamper-evident bags
- Document location in secure records
- Create multiple copies
- Store copies in different locations

❌ **Don't:**
- Leave in desk drawer
- Store with system
- Share with unauthorized personnel
- Connect to untrusted systems
- Store unencrypted location info

### Access Control

**Who should have recovery keys:**
- IT Security team
- System administrators
- C-level executives (for business continuity)

**Access procedure:**
1. Document who has keys
2. Require dual authorization for use
3. Log all recovery key usage
4. Audit key access regularly
5. Replace if compromised

### Handling Rogue Employee Scenario

**If employee locks out legitimate users:**

1. **Retrieve recovery USB** from secure storage
2. **Document incident** (who, when, why)
3. **Boot affected system**
4. **Insert recovery USB**
5. **Run recovery**: `sudo nubifer-recovery`
6. **Reset rogue user password** or disable account
7. **Create new admin account** if needed
8. **Review audit logs** for unauthorized actions
9. **Change all cloud credentials** accessed by rogue user
10. **Report to security team**

**Post-incident:**
- Review access controls
- Update security policies
- Consider additional monitoring
- Replace recovery key if compromised

## Creating Multiple Copies

**Recommended: 3 copies minimum**

```bash
# Create first copy
sudo nubifer-recovery-key-setup
# Store in primary safe

# Create second copy
sudo nubifer-recovery-key-setup
# Store in secondary location

# Create third copy
sudo nubifer-recovery-key-setup
# Store off-site
```

**Label each USB:**
```
NubiferOS Recovery Key
System: [hostname]
Copy: 1 of 3
Created: [date]
⚠️  SECURE STORAGE REQUIRED
```

## Testing Recovery Process

**Test quarterly:**

1. Schedule test during maintenance window
2. Retrieve recovery USB from storage
3. Test on non-production system first
4. Verify all recovery options work
5. Document test results
6. Return USB to secure storage

**Test checklist:**
- [ ] USB detected and mounted
- [ ] Recovery script runs
- [ ] Password reset works
- [ ] Drive unlocking works
- [ ] Emergency shell accessible
- [ ] Logs viewable

## Replacing Recovery Key

**Replace if:**
- Compromised or suspected compromise
- Lost or stolen
- Damaged or corrupted
- Personnel changes
- Regular rotation (annually)

**Replacement process:**
1. Create new recovery key
2. Test new key
3. Securely destroy old key (shred USB)
4. Update documentation
5. Notify authorized personnel

## Integration with LUKS Encryption

Recovery key can unlock LUKS encrypted drives:

```bash
# During setup, add to LUKS
sudo nubifer-recovery-key-setup
# Select "yes" when prompted to add to LUKS

# Manual addition later
sudo cryptsetup luksAddKey /dev/sda2 /media/NUBIFER_RECOVERY/recovery.key
```

**Benefits:**
- Unlock encrypted drives without passphrase
- Emergency data access
- Disaster recovery

**Security consideration:**
- Physical USB access = drive decryption
- Store USB as securely as LUKS passphrase

## Troubleshooting

### Recovery USB Not Detected

```bash
# Check if USB is recognized
lsblk

# Check for label
blkid | grep NUBIFER_RECOVERY

# Manual mount
sudo mount /dev/sdb1 /mnt
ls /mnt
```

### Recovery Script Fails

```bash
# Run script directly
sudo /media/NUBIFER_RECOVERY/recovery.sh

# Check permissions
ls -l /media/NUBIFER_RECOVERY/recovery.sh

# Fix permissions if needed
sudo chmod +x /media/NUBIFER_RECOVERY/recovery.sh
```

### USB Corrupted

If USB is corrupted:
1. Use backup copy
2. Create new recovery key
3. Destroy corrupted USB

### Lost All Recovery Keys

**If all recovery keys are lost:**
- Boot from live USB
- Mount encrypted drives (if you know passphrase)
- Create new recovery key
- **If passphrase also lost**: Data may be unrecoverable (encryption working as designed)

## Compliance and Auditing

### Documentation Requirements

Maintain records of:
- Recovery key creation dates
- Storage locations (in secure system)
- Authorized personnel
- Usage logs
- Test results
- Replacement history

### Audit Trail

Log all recovery key usage:
```bash
# Recovery usage is logged to
/var/log/nubifer/recovery.log

# View recovery audit log
sudo journalctl -u nubifer-recovery
```

### Compliance Considerations

**SOC 2:**
- Document recovery procedures
- Restrict physical access
- Log all usage
- Regular testing

**ISO 27001:**
- Include in business continuity plan
- Define access controls
- Regular audits

**HIPAA/PCI DSS:**
- Encrypt recovery key storage location records
- Dual authorization for access
- Audit all usage

## Emergency Contacts

**During recovery incident:**

1. **IT Security Team**: [Contact info]
2. **System Administrator**: [Contact info]
3. **Management**: [Contact info]
4. **Legal** (if rogue employee): [Contact info]

## FAQ

**Q: Can recovery key be used remotely?**  
A: No. Physical USB access required. This is by design - no backdoors.

**Q: What if USB is stolen?**  
A: Immediately create new recovery key and destroy old one. Review system access logs.

**Q: Can I use any USB drive?**  
A: Yes, but use high-quality USB drive. Recommend USB 3.0+ for reliability.

**Q: How long does recovery key last?**  
A: Indefinitely, but recommend annual replacement as best practice.

**Q: Can I have different keys for different systems?**  
A: Yes, each system should have its own recovery key.

**Q: What if I forget where I stored the USB?**  
A: This is why documentation and multiple copies are critical.

---

**Last Updated**: 2024-01-15  
**NubiferOS Version**: 1.0 (Nimbus)  
**Security Level**: Critical
