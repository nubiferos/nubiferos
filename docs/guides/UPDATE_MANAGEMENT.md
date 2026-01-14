# NubiferOS Update Management

## Overview

NubiferOS includes an automated update management system for cloud CLIs, SDKs, and development tools. The system checks for updates from various sources and provides a unified interface for keeping all tools up to date.

## Update Checker

### Installation

The update checker is installed by default at `/usr/local/bin/nubifer-update-checker`.

### Usage

```bash
# Check for updates
nubifer-update-checker check

# Force check (ignore cache)
nubifer-update-checker check --force

# Show update summary
nubifer-update-checker summary

# Update all tools
nubifer-update-checker update

# List installed versions
nubifer-update-checker list

# Show help
nubifer-update-checker help
```

### Update Sources

The update checker retrieves version information from official sources:

| Tool | Source | Method |
|------|--------|--------|
| AWS CLI | GitHub Releases | API |
| Azure CLI | PyPI | API |
| Google Cloud SDK | Release Notes | Web Scraping |
| Terraform | GitHub Releases | API |
| kubectl | Kubernetes Releases | API |
| Helm | GitHub Releases | API |
| Docker | GitHub Releases | API |
| eksctl | GitHub Releases | API |
| k9s | GitHub Releases | API |
| Trivy | GitHub Releases | API |

### Caching

- Update checks are cached for 24 hours
- Cache location: `~/.cache/nubifer-updates/`
- Use `--force` to bypass cache

### Automatic Updates

#### Enable Automatic Checks

Add to crontab for daily checks:

```bash
# Check for updates daily at 9 AM
0 9 * * * /usr/local/bin/nubifer-update-checker check

# Or use systemd timer (recommended)
sudo systemctl enable nubifer-update-checker.timer
sudo systemctl start nubifer-update-checker.timer
```

#### Systemd Timer (Create if needed)

`/etc/systemd/system/nubifer-update-checker.timer`:
```ini
[Unit]
Description=NubiferOS Update Checker Timer
Requires=nubifer-update-checker.service

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
```

`/etc/systemd/system/nubifer-update-checker.service`:
```ini
[Unit]
Description=NubiferOS Update Checker
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/nubifer-update-checker check
User=%u

[Install]
WantedBy=multi-user.target
```

## Update Process

### Manual Updates

```bash
# Check what needs updating
nubifer-update-checker check

# Review updates
nubifer-update-checker summary

# Update all tools
nubifer-update-checker update
```

### Selective Updates

Update individual tools using their native update methods:

#### AWS CLI
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install --update
```

#### Azure CLI
```bash
sudo apt-get update
sudo apt-get install --only-upgrade azure-cli
```

#### Google Cloud SDK
```bash
gcloud components update
```

#### Terraform
```bash
sudo apt-get update
sudo apt-get install --only-upgrade terraform
```

#### kubectl
```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

#### Helm
```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

## Update Notifications

### Desktop Notifications

Enable desktop notifications for updates:

```bash
# Install notification daemon
sudo apt-get install libnotify-bin

# Add to update checker
nubifer-update-checker check && \
  notify-send "NubiferOS" "Updates available. Run 'nubifer-update-checker summary'"
```

### Email Notifications

Configure email notifications:

```bash
# Install mail utilities
sudo apt-get install mailutils

# Add to crontab
0 9 * * * /usr/local/bin/nubifer-update-checker check && \
  /usr/local/bin/nubifer-update-checker summary | mail -s "NubiferOS Updates" user@example.com
```

## Version Tracking

### Current Versions

View all installed tool versions:

```bash
nubifer-update-checker list
```

Output:
```
==========================================
Installed Tool Versions
==========================================
aws-cli:        2.13.25
azure-cli:      2.53.0
gcloud:         450.0.0
terraform:      1.6.3
kubectl:        1.28.3
helm:           3.13.1
docker:         24.0.7
eksctl:         0.162.0
k9s:            0.28.2
trivy:          0.47.0
==========================================
```

### Version History

Track version changes over time:

```bash
# Log versions to file
nubifer-update-checker list >> ~/.nubifer/version-history.log
```

## Update Policies

### Recommended Update Schedule

| Tool Type | Update Frequency | Reason |
|-----------|-----------------|--------|
| Cloud CLIs | Weekly | New features, bug fixes |
| Security Tools | Immediately | Security patches |
| IaC Tools | Monthly | Stability, testing |
| Container Tools | Monthly | Stability |
| IDEs | As needed | Feature updates |

### Pre-Production Testing

Before updating production tools:

1. Check release notes
2. Test in development environment
3. Verify compatibility with existing scripts
4. Update documentation
5. Deploy to production

### Rollback Procedure

If an update causes issues:

```bash
# Reinstall specific version
# Example for Terraform
wget https://releases.hashicorp.com/terraform/1.5.0/terraform_1.5.0_linux_amd64.zip
unzip terraform_1.5.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/
```

## API Rate Limits

### GitHub API

- Unauthenticated: 60 requests/hour
- Authenticated: 5000 requests/hour

To use authenticated requests:

```bash
# Set GitHub token
export GITHUB_TOKEN=ghp_your_token_here

# Update checker will use token automatically
```

### Other APIs

- PyPI: No rate limit
- Kubernetes: No rate limit
- Cloud provider APIs: Varies

## Troubleshooting

### Update Check Fails

```bash
# Check internet connection
ping -c 1 github.com

# Check API access
curl -I https://api.github.com

# Clear cache and retry
rm -rf ~/.cache/nubifer-updates/
nubifer-update-checker check --force
```

### Version Detection Fails

```bash
# Verify tool is installed
which aws
which az
which gcloud

# Check tool version manually
aws --version
az version
gcloud version
```

### Update Fails

```bash
# Check permissions
sudo -v

# Check disk space
df -h

# Check for conflicts
sudo apt-get check

# Review logs
journalctl -xe
```

## Custom Update Sources

### Add Custom Tool

Edit `/usr/local/bin/nubifer-update-checker` and add:

```bash
# In get_installed_version()
my-tool)
    version=$(my-tool --version | awk '{print $2}')
    ;;

# In get_latest_version()
my-tool)
    version=$(curl -s https://api.example.com/version | jq -r '.version')
    ;;

# In check_all_tools()
check_tool "my-tool"
```

### RSS Feed Integration

For tools without APIs, use RSS feeds:

```bash
# Install RSS reader
sudo apt-get install rsstail

# Monitor release feed
rsstail -u https://github.com/tool/releases.atom -n 1
```

## Security Considerations

### Verify Downloads

Always verify checksums and signatures:

```bash
# Example for Terraform
wget https://releases.hashicorp.com/terraform/1.6.3/terraform_1.6.3_SHA256SUMS
wget https://releases.hashicorp.com/terraform/1.6.3/terraform_1.6.3_SHA256SUMS.sig
gpg --verify terraform_1.6.3_SHA256SUMS.sig terraform_1.6.3_SHA256SUMS
```

### Update Over Secure Channels

- Always use HTTPS
- Verify SSL certificates
- Use official repositories

### Review Release Notes

Before updating:
1. Read release notes
2. Check for breaking changes
3. Review security advisories
4. Test in non-production environment

## Integration with Package Managers

### APT Integration

Tools installed via APT are updated through system updates:

```bash
sudo apt-get update
sudo apt-get upgrade
```

### Manual Installation Tracking

For manually installed tools, the update checker provides:
- Version detection
- Update notifications
- Update scripts

## Monitoring

### Update Status Dashboard

Create a simple dashboard:

```bash
#!/bin/bash
# update-dashboard.sh

echo "NubiferOS Update Dashboard"
echo "=========================="
echo ""

nubifer-update-checker list

echo ""
echo "Updates Available:"
nubifer-update-checker summary | grep "Updates available"

echo ""
echo "Last Check:"
stat -c %y ~/.cache/nubifer-updates/versions.json 2>/dev/null || echo "Never"
```

### Metrics

Track update metrics:
- Time since last update
- Number of pending updates
- Update success rate
- Time to apply updates

## Best Practices

1. **Regular Checks**: Check for updates weekly
2. **Test First**: Test updates in development before production
3. **Read Release Notes**: Always review what's changing
4. **Backup**: Backup configurations before updating
5. **Monitor**: Watch for issues after updates
6. **Document**: Keep track of versions and changes
7. **Automate**: Use automated checks but manual updates
8. **Security First**: Prioritize security updates

## Support

### Documentation
- Update checker: `nubifer-update-checker help`
- Tool-specific docs: See browser bookmarks

### Troubleshooting
- GitHub Issues: https://github.com/nubiferos/nubiferos/issues
- Discord: https://discord.gg/nubiferos

---

**NubiferOS Version**: 1.0 (Nimbus)  
**Last Updated**: 2024-01-15
