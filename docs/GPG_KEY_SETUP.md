# GPG Key Setup for NubiferOS Maintainers

This guide explains how to set up GPG signing for NubiferOS ISO releases.

## Overview

NubiferOS ISOs are signed with GPG to allow users to verify authenticity. The signing happens automatically in GitHub Actions when the `GPG_PRIVATE_KEY` secret is configured.

## Creating a Signing Key

### 1. Generate a New GPG Key

```bash
# Generate a new key (use RSA 4096-bit for security)
gpg --full-generate-key
```

When prompted:
- Key type: `(1) RSA and RSA`
- Key size: `4096`
- Expiration: `2y` (2 years recommended, can be extended)
- Real name: `NubiferOS Release Signing`
- Email: `security@nubiferos.io` (or your project email)
- Comment: `ISO Release Signing Key`

### 2. Set a Strong Passphrase

Choose a strong passphrase. You'll need this for the `GPG_PASSPHRASE` secret.

### 3. Export the Private Key

```bash
# List keys to find the key ID
gpg --list-secret-keys --keyid-format LONG

# Export the private key (ASCII armored)
gpg --armor --export-secret-keys YOUR_KEY_ID > nubiferos-signing-key.asc
```

**⚠️ SECURITY WARNING**: The private key file is extremely sensitive. Never commit it to git, share it publicly, or store it unencrypted.

### 4. Export the Public Key

```bash
# Export public key for distribution
gpg --armor --export YOUR_KEY_ID > security/nubiferos-release-signing.pub
```

The public key should be committed to the repository so users can verify signatures.

## Configuring GitHub Actions

### Required Secrets

Add these secrets to your GitHub repository (Settings → Secrets and variables → Actions):

| Secret | Description |
|--------|-------------|
| `GPG_PRIVATE_KEY` | The full ASCII-armored private key (contents of `nubiferos-signing-key.asc`) |
| `GPG_PASSPHRASE` | The passphrase for the private key |

### Adding the Private Key Secret

1. Go to repository Settings → Secrets and variables → Actions
2. Click "New repository secret"
3. Name: `GPG_PRIVATE_KEY`
4. Value: Paste the entire contents of `nubiferos-signing-key.asc` including:
   ```
   -----BEGIN PGP PRIVATE KEY BLOCK-----
   ...
   -----END PGP PRIVATE KEY BLOCK-----
   ```
5. Click "Add secret"

### Adding the Passphrase Secret

1. Click "New repository secret"
2. Name: `GPG_PASSPHRASE`
3. Value: Your key passphrase
4. Click "Add secret"

## How Signing Works

When the build workflow runs:

1. The workflow checks if `GPG_PRIVATE_KEY` is configured
2. Creates a temporary GPG home directory (avoids permission issues)
3. Imports the private key
4. Signs the ISO with `gpg --detach-sign --armor`
5. Exports the public key alongside the ISO
6. Uploads signature (`.asc`) and public key to S3
7. Cleans up the temporary GPG directory

If no GPG key is configured, the build continues without signing.

## Verifying Signatures

Users can verify ISO signatures:

```bash
# Download the public key
curl -O https://<your-bucket-name>.s3.amazonaws.com/nubiferos-signing-key.pub

# Import the public key
gpg --import nubiferos-signing-key.pub

# Verify the signature
gpg --verify nubiferos-latest.iso.asc nubiferos-latest.iso
```

Expected output for valid signature:
```
gpg: Signature made [date]
gpg:                using RSA key [KEY_ID]
gpg: Good signature from "NubiferOS Release Signing <security@nubiferos.io>"
```

## Key Management Best Practices

### Key Storage

- Store the private key in a password manager or encrypted vault
- Keep an offline backup in a secure location
- Never store the private key in plain text

### Key Rotation

- Rotate keys every 2 years or if compromised
- When rotating:
  1. Generate new key
  2. Update GitHub secrets
  3. Update public key in repository
  4. Sign a transition statement with old key
  5. Announce the key change

### Revocation

If the key is compromised:

```bash
# Generate revocation certificate (do this when creating the key!)
gpg --gen-revoke YOUR_KEY_ID > revocation.asc

# If compromised, import the revocation
gpg --import revocation.asc

# Publish the revoked key to keyservers
gpg --send-keys YOUR_KEY_ID
```

### Multiple Maintainers

For teams with multiple maintainers:

1. **Option A**: Share a single signing key (simpler, less secure)
   - Store in team password manager
   - All maintainers use same key

2. **Option B**: Use subkeys (more secure)
   - Create signing subkeys for each maintainer
   - Revoke individual subkeys if needed

3. **Option C**: Separate keys per maintainer (most secure)
   - Each maintainer has their own key
   - Users trust multiple keys

## Troubleshooting

### "Permission denied" errors in CI

The workflow creates a temporary GNUPGHOME to avoid permission issues. If you still see errors:

```yaml
export GNUPGHOME=$(mktemp -d -t gpg-signing-XXXXXX)
chmod 700 "$GNUPGHOME"
```

### "No secret key" after import

Ensure the full private key block is in the secret, including headers:
```
-----BEGIN PGP PRIVATE KEY BLOCK-----
[key data]
-----END PGP PRIVATE KEY BLOCK-----
```

### Signature verification fails

1. Check the public key matches the signing key
2. Ensure the ISO wasn't modified after signing
3. Verify the `.asc` file corresponds to the correct ISO

## Security Checklist

Before enabling signing:

- [ ] Private key stored securely (not in git)
- [ ] Strong passphrase used
- [ ] Public key committed to repository
- [ ] GitHub secrets configured correctly
- [ ] Revocation certificate generated and stored safely
- [ ] Key expiration set (2 years recommended)
- [ ] Team members know the key rotation procedure

## Related Documentation

- [SECURITY_SCANNING.md](SECURITY_SCANNING.md) - Security scanning overview
- [GitHub Encrypted Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [GPG Best Practices](https://riseup.net/en/security/message-security/openpgp/best-practices)
