# CloudOS Components

This directory contains the custom components that make up CloudOS.

## Components

### Credential Manager
**Path**: `credential-manager/`

Secure credential storage and management service for cloud provider credentials.

**Features**:
- Encrypted credential storage using system keyring
- Support for multiple authentication methods (access keys, OIDC, IAM roles)
- D-Bus interface for credential access
- Automatic credential refresh
- Memory protection (mlock)

**Technology**: Python with libsecret integration

### Context Manager
**Path**: `context-manager/`

Workspace isolation and context switching service.

**Features**:
- Workspace creation and management
- Virtual desktop integration
- Environment variable injection per workspace
- Read-only mode enforcement
- D-Bus interface for workspace operations

**Technology**: Python/Go with D-Bus

### Resource Viewer
**Path**: `resource-viewer/`

GUI application for browsing and visualizing cloud resources locally.

**Features**:
- Local resource indexing from cloud providers
- Offline browsing capability
- Multi-cloud support (AWS, Azure, GCP)
- Resource relationship visualization
- Organization-wide dashboard
- Cost analysis

**Technology**: Electron/Tauri with React/Vue frontend, Python/Go backend

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
# Test all components
./test/test-components.sh

# Test individual component
pytest components/credential-manager/tests/
```

## Dependencies

Component dependencies are managed separately:
- Python: `requirements.txt` in component directory
- Node.js: `package.json` in component directory
- Go: `go.mod` in component directory
