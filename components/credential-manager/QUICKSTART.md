# Credential Manager Quick Start

## Installation

```bash
cd components/credential-manager
sudo ./install.sh
```

## First Time Setup

### 1. Create GPG Key (if you don't have one)

```bash
gpg --gen-key
```

Follow the prompts:
- Real name: Your Name
- Email: your@email.com
- Passphrase: Choose a strong passphrase

### 2. Initialize Pass Store

```bash
nubifer-creds init
```

This will:
- List your available GPG keys
- Prompt you to select one
- Initialize pass with that key

### 3. Check Status

```bash
nubifer-creds status
```

Should show:
- ✓ All prerequisites met
- GPG Key ID
- Database location
- Number of credentials stored

## Adding Credentials

### AWS

```bash
nubifer-creds add --provider aws --account-id 123456789012 --account-name "Production"
```

You'll be prompted for:
- AWS Access Key ID
- AWS Secret Access Key

### Azure

```bash
nubifer-creds add --provider azure --account-id my-subscription-id --account-name "Dev"
```

You'll be prompted for:
- Azure Client ID
- Azure Client Secret
- Azure Tenant ID

### GCP

```bash
nubifer-creds add --provider gcp --account-id my-project-id --account-name "Staging"
```

You'll be prompted for:
- Path to service account JSON key file

## Viewing Credentials

### List All

```bash
nubifer-creds list
```

### List by Provider

```bash
nubifer-creds list --provider aws
```

### Show Details

```bash
nubifer-creds show --provider aws --account-id 123456789012
```

### View Actual Values (via pass)

```bash
pass show nubiferos/credentials/aws/123456789012/access_key_id
pass show nubiferos/credentials/aws/123456789012/secret_access_key
```

## Testing Credentials

```bash
nubifer-creds test --provider aws --account-id 123456789012
```

## Deleting Credentials

```bash
nubifer-creds delete --provider aws --account-id 123456789012
```

## Common Tasks

### Export Credentials as JSON

```bash
nubifer-creds list --format json > credentials.json
```

### Check if Pass is Working

```bash
pass ls
```

Should show:
```
Password Store
└── nubiferos
    └── credentials
        ├── aws
        ├── azure
        └── gcp
```

### Backup GPG Key

```bash
# Export private key (keep this VERY secure!)
gpg --export-secret-keys --armor your@email.com > gpg-private-key.asc

# Export public key
gpg --export --armor your@email.com > gpg-public-key.asc
```

### Restore GPG Key

```bash
gpg --import gpg-private-key.asc
gpg --import gpg-public-key.asc
```

## Troubleshooting

### "Pass store not initialized"

Run: `nubifer-creds init`

### "No GPG keys found"

Create one: `gpg --gen-key`

### GPG Passphrase Prompts Too Frequent

Configure gpg-agent to cache passphrase:

```bash
# Edit ~/.gnupg/gpg-agent.conf
echo "default-cache-ttl 3600" >> ~/.gnupg/gpg-agent.conf
echo "max-cache-ttl 7200" >> ~/.gnupg/gpg-agent.conf

# Restart gpg-agent
gpgconf --kill gpg-agent
```

### Can't Find nubifer-creds Command

Check installation:
```bash
which nubifer-creds
# Should show: /usr/local/bin/nubifer-creds
```

If not found, reinstall:
```bash
sudo ./install.sh
```

## Security Tips

1. **Strong GPG Passphrase**: Use a long, unique passphrase
2. **Backup GPG Key**: Store backup in secure location (encrypted USB, password manager)
3. **Don't Share GPG Key**: Never share your private key
4. **Use Different Keys**: Consider separate GPG keys for different purposes
5. **Regular Backups**: Backup both GPG key and pass store regularly

## Integration with Workspace Manager

Once workspace manager is implemented, credentials will be automatically loaded based on active workspace:

```bash
# Create workspace with credentials
nubifer-workspace create \
  --name "AWS Production" \
  --provider aws \
  --account-id 123456789012 \
  --credential-id <from-nubifer-creds>

# Switch workspace (credentials auto-loaded)
nubifer-workspace switch <workspace-id>

# AWS CLI now uses credentials from active workspace
aws s3 ls
```

## Next Steps

- Add credentials for all your cloud accounts
- Test credential retrieval
- Integrate with workspace manager (coming soon)
- Set up automatic backups of GPG key and pass store
