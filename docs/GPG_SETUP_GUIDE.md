# GPG Key Setup for NubiferOS

## Overview

NubiferOS uses GPG (GNU Privacy Guard) to encrypt credentials stored in `pass` (password-store). You have two options for setting up your GPG key.

## Option 1: Automated Setup (Recommended for Most Users)

Use the setup wizard to automatically generate and configure everything:

```bash
nubifer-setup-wizard
```

The wizard will:
1. ✅ Check if GPG key exists (generate if needed)
2. ✅ Initialize pass with your key
3. ✅ Optionally set up git for backups
4. ✅ Guide you through adding your first credential

**Pros:**
- Quick and easy
- Handles all configuration
- Good defaults (RSA 4096-bit)
- Interactive guidance

**Cons:**
- Less control over key parameters
- Auto-generated key (no passphrase by default for ease of use)

### Usage

```bash
# Run setup wizard
nubifer-setup-wizard setup

# Check status
nubifer-setup-wizard status

# Backup your key
nubifer-setup-wizard backup
```

## Option 2: Manual Setup (Recommended for Advanced Users)

Generate your own GPG key with full control over all parameters:

### Step 1: Generate GPG Key

```bash
gpg --full-generate-key
```

**Recommended settings:**
- Key type: `(1) RSA and RSA`
- Key size: `4096` bits
- Expiration: `0` (no expiration) or `2y` (2 years)
- Real name: Your name
- Email: Your email
- Passphrase: **Strong passphrase** (20+ characters)

### Step 2: Initialize pass

```bash
# Get your key ID
gpg --list-keys

# Initialize pass with your key
pass init your-email@example.com

# Or use key ID
pass init 1234567890ABCDEF1234567890ABCDEF12345678
```

### Step 3: Optional - Set up git

```bash
# Initialize git repository
pass git init

# Add remote (for backup/sync)
pass git remote add origin git@github.com:yourusername/password-store.git

# Push to remote
pass git push -u origin main
```

**Pros:**
- Full control over key parameters
- Can set strong passphrase
- Can set expiration date
- More secure for production use

**Cons:**
- More steps
- Need to understand GPG options
- Must remember passphrase

## Comparison

| Feature | Automated | Manual |
|---------|-----------|--------|
| Setup time | 2 minutes | 5 minutes |
| Passphrase | None (easier) | Required (more secure) |
| Key size | 4096-bit | Your choice |
| Expiration | Never | Your choice |
| Control | Limited | Full |
| Best for | Testing, Development | Production, Security-focused |

## Which Should You Choose?

### Use Automated Setup If:
- ✅ You're testing NubiferOS
- ✅ You want quick setup
- ✅ You're new to GPG
- ✅ You're using this for development only
- ✅ You trust the defaults

### Use Manual Setup If:
- ✅ You need production-grade security
- ✅ You want a passphrase-protected key
- ✅ You need key expiration
- ✅ You're familiar with GPG
- ✅ You have specific security requirements
- ✅ You're managing sensitive credentials

## Hybrid Approach (Recommended)

**For most users, we recommend:**

1. **Start with automated setup** for quick testing
2. **Switch to manual setup** when moving to production

```bash
# Initial setup (automated)
nubifer-setup-wizard

# Test everything works
nubifer-creds add --type aws --name test
nubifer-creds list

# Later, for production (manual)
gpg --full-generate-key  # With strong passphrase
pass init new-key-id
# Migrate credentials to new key
```

## Security Considerations

### Automated Setup Security

**What it does:**
- Generates RSA 4096-bit key (secure)
- No passphrase (convenient but less secure)
- No expiration (convenient but less secure)

**Security level:** Good for development, acceptable for personal use

**Risks:**
- If someone gains access to your system, they can access credentials
- No passphrase means no second factor of protection

**Mitigations:**
- Use full disk encryption (LUKS)
- Lock your screen when away
- Use strong user password
- Backup key securely

### Manual Setup Security

**What you control:**
- Passphrase strength (your responsibility)
- Key expiration (forces rotation)
- Key parameters (algorithm, size)

**Security level:** Excellent for production, required for sensitive data

**Risks:**
- Forgetting passphrase = losing all credentials
- Weak passphrase = false sense of security

**Mitigations:**
- Use strong passphrase (20+ characters)
- Store passphrase in secure location (not digitally!)
- Backup key securely
- Set expiration and rotate keys

## Adding Passphrase to Automated Key

If you used automated setup but want to add a passphrase:

```bash
# Edit your key
gpg --edit-key your-email@example.com

# At the gpg> prompt:
gpg> passwd
# Enter new passphrase
gpg> save
```

## Backup Your Key (CRITICAL!)

**Regardless of which method you use, BACKUP YOUR KEY!**

### Backup Private Key

```bash
# Using wizard
nubifer-setup-wizard backup

# Or manually
gpg --export-secret-keys --armor your-email@example.com > gpg-backup.asc
chmod 600 gpg-backup.asc
```

### Store Backup Securely

**Good locations:**
- ✅ Encrypted USB drive (stored in safe)
- ✅ Hardware security key (YubiKey)
- ✅ Encrypted cloud storage (with strong password)
- ✅ Paper backup (for passphrase, stored securely)

**Bad locations:**
- ❌ Unencrypted USB drive
- ❌ Email
- ❌ Cloud storage without encryption
- ❌ Git repository
- ❌ Shared network drive

### Restore from Backup

```bash
# Import private key
gpg --import gpg-backup.asc

# Trust the key
gpg --edit-key your-email@example.com
gpg> trust
gpg> 5 (ultimate trust)
gpg> save

# Reinitialize pass
pass init your-email@example.com
```

## Troubleshooting

### "No GPG key found"

```bash
# Check if you have any keys
gpg --list-keys

# If empty, generate one
gpg --full-generate-key
# or
nubifer-setup-wizard
```

### "pass not initialized"

```bash
# Initialize with your key
pass init your-email@example.com
```

### "Permission denied"

```bash
# Fix permissions
chmod 700 ~/.gnupg
chmod 600 ~/.gnupg/*
```

### "Inappropriate ioctl for device"

```bash
# Set GPG_TTY
export GPG_TTY=$(tty)

# Add to ~/.bashrc
echo 'export GPG_TTY=$(tty)' >> ~/.bashrc
```

### Forgot Passphrase

**Unfortunately, if you forget your GPG passphrase, you cannot recover it.**

Options:
1. Generate new key
2. Restore from backup (if you have one)
3. Re-enter all credentials

**This is why backup is critical!**

## Best Practices

### For Development
1. Use automated setup for speed
2. Backup key anyway
3. Use full disk encryption
4. Lock screen when away

### For Production
1. Use manual setup with strong passphrase
2. Set key expiration (1-2 years)
3. Backup key to multiple secure locations
4. Document key ID and email used
5. Test restore procedure
6. Rotate keys on schedule

### For Teams
1. Each person has their own GPG key
2. Use pass with multiple recipients
3. Store team keys in secure location
4. Document key management procedures
5. Have key recovery process

## Migration Between Keys

### From Automated to Manual

```bash
# 1. Generate new key manually
gpg --full-generate-key

# 2. Export credentials
pass git init  # If not already done
pass git add -A
pass git commit -m "Before key migration"

# 3. Re-encrypt with new key
pass init new-key-id

# 4. Verify
pass show nubifer/default/cloud/aws/production/access-key-id

# 5. Backup old key (just in case)
gpg --export-secret-keys --armor old-email@example.com > old-key-backup.asc
```

## Summary

**Quick Start (Testing):**
```bash
nubifer-setup-wizard
```

**Production Setup:**
```bash
gpg --full-generate-key  # RSA 4096, strong passphrase
pass init your-email@example.com
nubifer-setup-wizard backup
```

**Key Points:**
- ✅ Automated = quick and easy
- ✅ Manual = more secure
- ✅ Always backup your key
- ✅ Use passphrase for production
- ✅ Test restore procedure

---

**NubiferOS Version**: 1.0 (Nimbus)  
**Last Updated**: 2024-01-15
