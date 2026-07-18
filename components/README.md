# NubiferOS Components

This directory contains the custom components that make up NubiferOS.

## Components

### Credential Manager
**Path**: `credential-manager/`

Workspace-scoped credential storage for cloud provider credentials, built on `pass` (password-store) with GPG encryption.

**Features**:
- GPG-encrypted storage via pass under `nubifer/<workspace-id>/...` — no plaintext secrets on disk
- AWS, Azure service principal, GCP service account, and API token credential types
- AWS CLI integration via `credential_process` (`nubifer-aws-credential-helper`) — no `~/.aws/credentials`
- STS token mode (default for AWS): CLIs get short-lived session tokens, base keys stay encrypted
- Audit log of every add/access/remove (paths only, never values)

**Technology**: Python wrapping `pass`/GnuPG; boto3 for STS. Ships as `nubifer-creds` + `nubifer-aws-credential-helper`. (The D-Bus service and SQLite metadata DB under `src/` are legacy, unshipped — see the component README.)

### Context Manager
**Path**: `context-manager/`

Workspace isolation and context switching service.

**Features**:
- Workspace state tracking and switching
- Environment variable injection per workspace
- Read-only mode enforcement
- D-Bus interface (`org.nubiferos.ContextManager`) for workspace operations, auto-started as a systemd user service

**Technology**: Python with D-Bus (dbus-python). The user-facing CLI is `nubifer-workspace` in `workspace-manager/`; this service backs it and the desktop integration.

### Resource Viewer
**Path**: `resource-viewer/`

GTK3 desktop application for browsing a locally cached inventory of your cloud resources.

**Features**:
- AWS resource indexing via boto3 (EC2, S3, Lambda, RDS, VPC) into a local SQLite database (`~/.local/share/nubifer/resources.db`, 0600)
- Offline browsing of cached inventory with "last synced" indicator; failed/partial syncs keep cached data visible
- Tree view grouped by provider > service > resource with live search (name, ID, type, region) and a detail pane showing all resource properties
- Manual sync with progress bar; per-service and per-region error isolation
- Uses the default boto3 credential chain (works with the credential manager's `credential_process` integration)
- Ships as GUI (`nubifer-resources`) plus CLI indexer (`nubifer-resource-sync`)

**Technology**: Python with GTK3 (PyGObject), boto3, SQLite. Currently AWS-only; Azure/GCP indexing, relationship visualization, and cost analysis are not yet implemented.

### Context Indicator
**Path**: `context-indicator/`

Desktop indicator widget showing current cloud context.

**Features**:
- Always-visible context display
- Color-coded by cloud provider
- Workspace switcher menu
- Terminal prompt integration
- Read-only mode indicator

**Technology**: GNOME Shell extension (JavaScript), KDE Plasmoid (QML)

## Development

Each component has its own directory structure:

```
component-name/
├── src/           # Source code
├── tests/         # Unit and integration tests
├── config/        # Configuration files
├── docs/          # Component-specific documentation
└── README.md      # Component README
```

## Building Components

See individual component README files for build instructions.

## Testing Components

```bash
# Repo-wide test suite
./tests/run-tests.sh

# Test individual component
pytest components/credential-manager/tests/
```

## Dependencies

Components are Python or shell — there is no Node.js or Go tooling in this repo. Python components declare dependencies in a `requirements.txt` in their directory; the GNOME Shell extension (`context-indicator/`) is plain JavaScript with no build step. What actually gets installed is determined by `build/build-iso.sh` and `build/build-debs.sh`, not by the per-component `install.sh` scripts (several of those are stale).
