# NubiferOS Credential Manager

Secure credential management for cloud accounts using pass (password-store) with GPG encryption.

## Architecture

- **Storage Backend**: `pass` (password-store) with GPG encryption
- **Metadata Database**: SQLite for credential metadata (no actual secrets)
- **D-Bus Interface**: System-wide credential service
- **CLI Tool**: `nubifer-creds` command-line interface

## Features

- ✅ Secure credential storage using GPG encryption (via pass)
- ✅ Support for AWS, Azure, and GCP credentials
- ✅ SQLite metadata database (stores only paths, not secrets)
- ✅ D-Bus interface for system integration
- ✅ Command-line interface
- ✅ Credential validation and testing
- ✅ No plain-text credentials on disk

## Installation

```bash
cd components/credential-manager
sudo ./install.sh
```

## Prerequisites

1. **GPG Key**: Required for pass encryption
   ```bash
   gpg --gen-key
   ```

2. **Pass Store**: Initialize with your GPG key
   ```bash
   nubifer-creds init
   ```

## Usage

### Initialize Pass Store

```bash
# Check status
nubifer-creds status

# Initialize (if not already done)
nubifer-creds init
```

### Add Credentials

**AWS:**
```bash
nubifer-creds add \
  --provider aws \
  --account-id 123456789012 \
  --account-name "Production"
# Will prompt for: AWS Access Key ID, AWS Secret Access Key
```

**Azure:**
```bash
nubifer-creds add \
  --provider azure \
  --account-id my-subscription-id \
  --account-name "Dev Subscription"
# Will prompt for: Client ID, Client Secret, Tenant ID
```

**GCP:**
```bash
nubifer-creds add \
  --provider gcp \
  --account-id my-project-id \
  --account-name "Production Project"
# Will prompt for: Path to service account JSON key file
```

### List Credentials

```bash
# List all credentials
nubifer-creds list

# List by provider
nubifer-creds list --provider aws

# JSON output
nubifer-creds list --format json
```

### Show Credential Details

```bash
nubifer-creds show --provider aws --account-id 123456789012
```

### Test Credentials

```bash
nubifer-creds test --provider aws --account-id 123456789012
```

### Delete Credentials

```bash
nubifer-creds delete --provider aws --account-id 123456789012
```

## Pass Store Structure

Credentials are stored in pass with the following structure:

```
~/.password-store/
└── nubiferos/
    └── credentials/
        ├── aws/
        │   └── 123456789012/
        │       ├── access_key_id.gpg
        │       └── secret_access_key.gpg
        ├── azure/
        │   └── subscription-id/
        │       ├── client_id.gpg
        │       ├── client_secret.gpg
        │       └── tenant_id.gpg
        └── gcp/
            └── project-id/
                └── service_account_key.gpg
```

## Metadata Database

SQLite database at `~/.config/nubiferos/credentials.db`:

```sql
CREATE TABLE credentials (
    id INTEGER PRIMARY KEY,
    provider TEXT NOT NULL,
    account_id TEXT NOT NULL,
    account_name TEXT NOT NULL,
    auth_type TEXT NOT NULL,
    pass_path_prefix TEXT NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    UNIQUE(provider, account_id)
);
```

**Important**: The database stores only metadata. Actual credentials are stored encrypted in pass.

## D-Bus Interface

**Service Name**: `org.nubiferos.CredentialManager`  
**Object Path**: `/org/nubiferos/CredentialManager`  
**Interface**: `org.nubiferos.CredentialManager`

### Methods

- `AddCredential(provider, account_id, account_name, credentials) -> (success, message)`
- `GetCredential(provider, account_id) -> credentials_dict`
- `ListAccounts(provider) -> list_of_accounts`
- `DeleteCredential(provider, account_id) -> (success, message)`
- `TestCredential(provider, account_id) -> (success, message)`
- `CheckPrerequisites() -> (success, issues_list)`

### Example D-Bus Usage

```python
import dbus

bus = dbus.SessionBus()
service = bus.get_object(
    'org.nubiferos.CredentialManager',
    '/org/nubiferos/CredentialManager'
)

# Add credential
credentials = {
    'access_key_id': 'AKIAIOSFODNN7EXAMPLE',
    'secret_access_key': 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY'
}
success, msg = service.AddCredential(
    'aws', '123456789012', 'Production', credentials,
    dbus_interface='org.nubiferos.CredentialManager'
)

# List accounts
accounts = service.ListAccounts(
    'aws',
    dbus_interface='org.nubiferos.CredentialManager'
)
```

## Security

### What's Encrypted

- ✅ All credential values (via GPG in pass)
- ✅ Pass store is encrypted at rest
- ✅ GPG passphrase required to access credentials

### What's NOT Encrypted

- ❌ Metadata in SQLite (provider, account_id, account_name, timestamps)
- ❌ Pass store structure (directory names visible)

### Security Best Practices

1. **Strong GPG Passphrase**: Use a strong passphrase for your GPG key
2. **GPG Agent**: Configure gpg-agent for passphrase caching
3. **Backup GPG Key**: Backup your GPG private key securely
4. **File Permissions**: Pass automatically sets secure permissions (600)
5. **No Logging**: Credential values are never logged

## Manual Testing

```bash
# 1. Add AWS credentials
nubifer-creds add --provider aws --account-id 123456789012 --account-name prod

# 2. Verify in pass
pass show nubiferos/credentials/aws/123456789012/access_key_id
pass show nubiferos/credentials/aws/123456789012/secret_access_key

# 3. List credentials
nubifer-creds list --provider aws

# 4. Test retrieval
nubifer-creds test --provider aws --account-id 123456789012

# 5. Show details
nubifer-creds show --provider aws --account-id 123456789012

# 6. Delete
nubifer-creds delete --provider aws --account-id 123456789012
```

## Troubleshooting

### Pass not initialized

```
Error: Pass store not initialized
```

**Solution**: Run `nubifer-creds init` to initialize pass with your GPG key.

### No GPG keys found

```
Error: No GPG keys found
```

**Solution**: Create a GPG key:
```bash
gpg --gen-key
```

### GPG passphrase prompts

If you're prompted for your GPG passphrase frequently, configure gpg-agent:

```bash
# ~/.gnupg/gpg-agent.conf
default-cache-ttl 3600
max-cache-ttl 7200
```

Then restart gpg-agent:
```bash
gpgconf --kill gpg-agent
```

## Development

### Project Structure

```
components/credential-manager/
├── src/
│   ├── pass_backend.py       # Pass wrapper
│   ├── credential_service.py # Core service logic
│   ├── dbus_interface.py     # D-Bus service
│   └── cli.py                # CLI tool
├── requirements.txt          # Python dependencies
├── install.sh                # Installation script
└── README.md                 # This file
```

### Running Tests

```bash
# Syntax check
python3 -m py_compile src/*.py

# Manual testing
./src/cli.py status
./src/cli.py list
```

## Future Enhancements (Deferred to Beta)

- [ ] Systemd service for D-Bus interface
- [ ] OIDC/SSO authentication
- [ ] Hardware key support (YubiKey)
- [ ] Automatic credential rotation
- [ ] Credential expiration warnings
- [ ] Audit logging
- [ ] Multi-user support

## License

Part of NubiferOS - GPL-3.0
