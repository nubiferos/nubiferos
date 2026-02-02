# NubiferOS Unified CLI

A unified kubectl-style CLI for NubiferOS that consolidates all CLI tools into a single interface.

## Installation

### From Source (Development)

```bash
# Create virtual environment
python3 -m venv .venv
source .venv/bin/activate

# Install in editable mode with dev dependencies
pip install -e ".[dev]"
```

### System-wide Installation

```bash
# Install system-wide (requires sudo)
sudo pip install .

# Or use the install script
./install.sh
```

## Usage

```bash
# Show help
nubifer --help

# Show version
nubifer --version
```

## Commands

### Workspace Management (`workspace` / `ws`)

Manage isolated cloud workspaces with their own credentials and settings.

```bash
# Create a new workspace
nubifer workspace create -n my-aws-prod -p aws -r us-east-1 -a 123456789012

# List all workspaces
nubifer ws list

# Switch to a workspace
nubifer ws switch my-aws-prod

# Show current workspace
nubifer ws current

# Enable read-only mode (lock)
nubifer ws ro

# Enable read-write mode (unlock)
nubifer ws rw -d 30  # Auto-revert after 30 minutes

# Delete a workspace
nubifer ws delete my-aws-prod
```

### Credential Management (`creds` / `c`)

Securely manage cloud credentials using GPG-encrypted storage.

```bash
# Add AWS credentials
nubifer creds add -t aws -n default

# List credentials
nubifer c list

# Show credential (masked)
nubifer c show -t aws -n default

# Remove credential
nubifer c remove nubifer/workspace-id/cloud/aws/default
```

**Security Note:** Credentials are NEVER stored in environment variables. They are retrieved on-demand from the encrypted pass store.

### Security Scanning (`scan` / `s`)

Run vulnerability and compliance scans.

```bash
# Run vulnerability scan
nubifer scan vuln

# Run compliance audit
nubifer s compliance

# Run all scans
nubifer s full

# Output as JSON
nubifer s full --json
```

### Dashboard (`dashboard` / `d`)

Launch the GTK security dashboard.

```bash
nubifer dashboard
# or
nubifer d
```

### Version (`version` / `v`)

Show version information.

```bash
# Show CLI version
nubifer version

# Show all component versions
nubifer v --verbose
```

### Configuration (`config` / `cfg`)

Manage CLI configuration.

```bash
# Show all config
nubifer config show

# Set a value
nubifer cfg set default_provider azure

# Reset to defaults
nubifer cfg reset
```

## Command Aliases

| Full Command | Alias |
|--------------|-------|
| `workspace`  | `ws`  |
| `creds`      | `c`   |
| `scan`       | `s`   |
| `dashboard`  | `d`   |
| `version`    | `v`   |
| `config`     | `cfg` |

## Shell Completion

```bash
# Install completion for your shell
nubifer --install-completion

# Or show completion script
nubifer --show-completion bash
```

## Configuration

Configuration is stored in `~/.config/nubifer/cli.yaml`:

```yaml
default_provider: aws
default_region: us-east-1
output_format: text
color_enabled: true
```

## Exit Codes

| Code | Meaning |
|------|---------|
| 0    | Success |
| 1    | General error |
| 2    | Critical security issue |

## Security

This CLI follows NubiferOS security principles:

- **No credentials in environment variables** - Credentials are retrieved on-demand from the encrypted pass store
- **Workspace isolation** - Each workspace has its own credential namespace
- **Read-only by default** - Workspaces start in read-only mode to prevent accidental changes
- **Credential masking** - Secrets are partially masked when displayed

## Development

```bash
# Run tests
pytest

# Run tests with coverage
pytest --cov=nubifer_cli

# Run property-based tests
pytest -v tests/
```

## License

MIT License - See LICENSE file for details.
