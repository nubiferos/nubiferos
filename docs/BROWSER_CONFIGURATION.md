# NubiferOS Browser Configuration

## Included Browsers

### Firefox ESR (Primary - Hardened)
- **Version**: Extended Support Release (ESR)
- **Purpose**: Primary browser with security hardening
- **Pre-installed Extensions**:
  - Multi-Account Containers
  - uBlock Origin
- **Status**: Installed by default

### Brave (Optional - Privacy-focused)
- **Version**: Latest stable
- **Purpose**: Chromium-based alternative
- **Features**: Built-in ad/tracker blocking
- **Status**: Selectable during installation

## Firefox Multi-Account Containers

### Pre-configured Containers

NubiferOS comes with pre-configured containers for each cloud provider:

| Container | Color | Use Case |
|-----------|-------|----------|
| **AWS** | 🟠 Orange (#FF9900) | AWS Console, AWS services |
| **Azure** | 🔵 Blue (#0078D4) | Azure Portal, Azure services |
| **GCP** | 🔴 Red (#EA4335) | GCP Console, GCP services |
| **Personal** | 🟢 Green | Personal browsing |

### How Containers Work

- **Isolated cookies/sessions** - Each container has separate cookies
- **Color-coded tabs** - Easy visual identification
- **Prevents tracking** - Sites can't track you across containers
- **Perfect for multi-account** - Use different AWS accounts in different containers

### Using Containers

1. **Right-click** on a link → "Open Link in New Container Tab"
2. **Click** the container icon in the URL bar to switch
3. **Assign sites** to always open in specific containers

### Integration with NubiferOS Workspaces

Containers complement NubiferOS workspaces:
- **Workspace** = OS-level isolation (credentials, environment)
- **Container** = Browser-level isolation (cookies, sessions)

**Example workflow:**
1. Switch to "AWS Production" workspace (OS level)
2. Open Firefox in "AWS" container (browser level)
3. All AWS credentials and browser sessions isolated

## Security Hardening

### Privacy Features Enabled

✅ **Tracking Protection** - Strict mode  
✅ **HTTPS-Only Mode** - Force encrypted connections  
✅ **DNS over HTTPS** - Encrypted DNS queries  
✅ **First-Party Isolation** - Prevent cross-site tracking  
✅ **Fingerprinting Resistance** - Harder to track  

### Disabled Features

❌ **Telemetry** - No data sent to Mozilla  
❌ **Firefox Studies** - No experiments  
❌ **Pocket** - Removed  
❌ **WebRTC** - Prevents IP leaks  
❌ **Geolocation** - No location tracking  

### Security Enhancements

- TLS 1.3 minimum
- OCSP stapling enabled
- Certificate pinning enforced
- Safe browsing enabled
- Dangerous downloads blocked

## Pre-configured Bookmarks

### Bookmark Structure

```
📁 AWS
  - AWS Console, SSO Portal, Documentation
  - AWS CLI Reference, SDK Documentation
  - Service Health Dashboard, Cost Explorer
  - CloudWatch, IAM, EC2, S3, Lambda, RDS, EKS
  - CloudFormation, Systems Manager
  - AWS re:Post Community
  
📁 Azure
  - Azure Portal, DevOps, Documentation
  - Azure CLI Reference
  - Status, Cost Management
  - Active Directory, VMs, Storage, Functions
  - Kubernetes Service
  
📁 Google Cloud
  - GCP Console, Documentation
  - gcloud CLI Reference
  - Status Dashboard, Billing
  - IAM, Compute Engine, Cloud Storage
  - Cloud Functions, Kubernetes Engine
  
📁 Infrastructure as Code
  - Terraform Registry, Documentation, Best Practices
  - Terraform AWS/Azure/GCP Provider docs
  - Pulumi Documentation and Registry
  - Ansible Documentation and Galaxy
  - AWS CDK Documentation
  - Bicep Documentation
  
📁 Kubernetes
  - Kubernetes Documentation and API Reference
  - Helm Documentation and Artifact Hub
  - kubectl Cheat Sheet
  - k9s and Kustomize documentation
  - CNCF Landscape
  - EKS, AKS, GKE best practices
  
📁 Containers & Docker
  - Docker Documentation, Hub, Compose docs
  - Podman Documentation
  - Container Registries (ECR, ACR, GCR, GitHub)
  - Trivy Documentation
  
📁 CI/CD & GitOps
  - GitHub Actions, GitLab CI/CD, Azure Pipelines
  - ArgoCD, Flux, Tekton, Jenkins documentation
  - Skaffold documentation
  
📁 Testing & Quality
  - k6, Locust, Newman (load testing)
  - Selenium, Playwright, Cypress (browser testing)
  - Pytest, Robot Framework (test frameworks)
  - SonarQube documentation
  
📁 Databases
  - PostgreSQL, MySQL, MongoDB, Redis documentation
  - DynamoDB, Cosmos DB, Cloud SQL documentation
  
📁 IDE Extensions
  - VS Code Marketplace
  - AWS, Azure, Google Cloud IDE extensions
  - Terraform, Docker, Kubernetes extensions
  - JetBrains Plugin Marketplace
  
📁 Developer Resources
  - GitHub, GitLab with CLI documentation
  - Stack Overflow, DevDocs
  - Regex101, JSON Formatter, YAML Validator
  
📁 Monitoring & Observability
  - Grafana, Prometheus, Loki documentation
  - Prometheus Query Examples
  - Datadog and New Relic platforms with docs
  
📁 Security & Compliance
  - AWS Security Hub, Azure Security Center, GCP SCC
  - Trivy, OWASP, OWASP ZAP documentation
  - CVE Database, Snyk Documentation
  - HashiCorp Vault, SOPS documentation
  
📁 Learning Resources
  - AWS Training, Azure Learn, Google Cloud Skills Boost
  - Terraform, Kubernetes, Docker tutorials
  - Linux Academy
  
📁 NubiferOS
  - Documentation, GitHub, Discord
  - Report Issue
```

**Note**: All bookmarks include direct links to official documentation for installed tools, making it easy to reference while working.

### Importing Bookmarks

Bookmarks are automatically available at:
```
/usr/share/nubifer/browser/firefox-bookmarks.json
```

**To import:**
1. Open Firefox
2. Bookmarks → Manage Bookmarks
3. Import and Backup → Import Bookmarks from JSON
4. Select `/usr/share/nubifer/browser/firefox-bookmarks.json`

Or run:
```bash
/usr/share/nubifer/browser/import-bookmarks.sh
```

## Browser Configuration Files

### Firefox Hardening
Location: `/etc/firefox/syspref.js`

Contains all privacy and security preferences.

### Firefox Policies
Location: `/etc/firefox/policies/policies.json`

Enterprise policies for:
- Extension management
- Privacy settings
- Homepage configuration
- Search engine defaults

### Container Configuration
Location: `/usr/share/nubifer/browser/containers/containers.json`

Defines pre-configured containers with colors and icons.

## Customization

### Adding Custom Bookmarks

Edit: `/usr/share/nubifer/browser/firefox-bookmarks.json`

Then re-import or add manually in Firefox.

### Adding Custom Containers

1. Open Firefox
2. Click container icon in toolbar
3. "Manage Containers"
4. Add new container with custom name/color

### Modifying Security Settings

Edit: `/etc/firefox/syspref.js`

**Warning**: Changing security settings may reduce privacy/security.

### Adding Extensions

**Recommended extensions** (not pre-installed):
- **Bitwarden** - Password manager (integrates with Credential Manager)
- **Privacy Badger** - Additional tracker blocking
- **HTTPS Everywhere** - Force HTTPS (mostly redundant with HTTPS-Only mode)
- **Decentraleyes** - Local CDN emulation
- **ClearURLs** - Remove tracking parameters from URLs

**Cloud-specific extensions:**
- **AWS Extend Switch Roles** - Quick AWS account switching
- **Azure Account Extension** - Azure account management
- **GCP Console Colorizer** - Color-code GCP projects

## Browser Shortcuts

### Container Shortcuts

- **Ctrl+Shift+1** - Open in AWS container
- **Ctrl+Shift+2** - Open in Azure container
- **Ctrl+Shift+3** - Open in GCP container
- **Ctrl+Shift+4** - Open in Personal container

### Useful Firefox Shortcuts

- **Ctrl+Shift+P** - Private window
- **Ctrl+Shift+Del** - Clear browsing data
- **Ctrl+Shift+K** - Web Console (DevTools)
- **Ctrl+Shift+E** - Network Monitor
- **F12** - Developer Tools

## Integration with NubiferOS Components

### Credential Manager Integration

Firefox can integrate with NubiferOS Credential Manager:
- Bitwarden extension connects to local credential storage
- No passwords stored in Firefox
- Credentials injected per workspace

### Context Indicator Integration

Browser container colors match workspace colors:
- AWS workspace → Orange theme → AWS container
- Azure workspace → Blue theme → Azure container
- GCP workspace → Red theme → GCP container

### Resource Viewer Integration

Resource Viewer can open cloud consoles in correct container:
```bash
nubifer-resource open ec2-instance --browser-container aws
```

## Troubleshooting

### Containers Not Working

1. Check if containers are enabled:
   ```
   about:config → privacy.userContext.enabled → true
   ```

2. Reinstall Multi-Account Containers extension

### Bookmarks Not Imported

Run import script:
```bash
/usr/share/nubifer/browser/import-bookmarks.sh
```

Or import manually from `/usr/share/nubifer/browser/firefox-bookmarks.json`

### Extensions Not Installing

Check Firefox policies:
```bash
cat /etc/firefox/policies/policies.json
```

Manually install from:
- uBlock Origin: https://addons.mozilla.org/firefox/addon/ublock-origin/
- Multi-Account Containers: https://addons.mozilla.org/firefox/addon/multi-account-containers/

### Performance Issues

1. Clear cache: Ctrl+Shift+Del
2. Disable hardware acceleration: about:preferences → Performance
3. Reduce container count
4. Check available RAM

## Security Best Practices

### Do's ✅

- Use containers for different cloud accounts
- Keep Firefox updated
- Use HTTPS-Only mode
- Enable DNS over HTTPS
- Use strong master password (if using password manager)
- Clear cache regularly
- Review extension permissions

### Don'ts ❌

- Don't disable tracking protection
- Don't install untrusted extensions
- Don't save passwords in Firefox (use Credential Manager)
- Don't disable HTTPS-Only mode
- Don't share containers between accounts
- Don't ignore security warnings

## Updates

### Firefox Updates

Firefox ESR updates automatically via:
```bash
sudo apt update && sudo apt upgrade firefox-esr
```

### Extension Updates

Extensions update automatically when Firefox restarts.

### Bookmark Updates

NubiferOS bookmark updates will be available via:
```bash
nubifer-tools update-bookmarks
```

## Support

### Firefox Issues
- Firefox Support: https://support.mozilla.org/
- Firefox ESR: https://www.mozilla.org/firefox/enterprise/

### Container Issues
- Multi-Account Containers: https://github.com/mozilla/multi-account-containers

### NubiferOS Browser Issues
- GitHub Issues: https://github.com/nubiferos/nubiferos/issues
- Discord: https://discord.gg/nubiferos

---

**Last Updated**: 2024-01-15  
**NubiferOS Version**: 1.0 (Nimbus)
