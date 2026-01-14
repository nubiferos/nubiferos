# NubiferOS Quick Reference

Quick reference guide for common tasks and features.

## IDE Plugins

### Install IDE Plugins
```bash
sudo /usr/local/bin/install-ide-plugins
```

Automatically installs plugins for:
- Terraform, Docker, Kubernetes
- AWS, Azure, GCP toolkits
- Python, Go, Java support
- Git integration

**Documentation**: [IDE Plugins Guide](IDE_PLUGINS.md)

## Browser Bookmarks

All installed tools have documentation bookmarked in Firefox:

### Access Bookmarks
1. Open Firefox
2. Bookmarks menu → Show All Bookmarks
3. Navigate to organized folders:
   - AWS, Azure, GCP (consoles + docs)
   - Infrastructure as Code (Terraform, Pulumi, Ansible)
   - Kubernetes (K8s, Helm, kubectl)
   - Containers & Docker
   - CI/CD & GitOps
   - Testing & Quality
   - Databases
   - IDE Extensions
   - Learning Resources

**Documentation**: [Browser Configuration](BROWSER_CONFIGURATION.md)

## Cloud Tools

### Verify Installed Tools
```bash
verify-cloud-tools
```

### AWS Tools
```bash
aws --version              # AWS CLI
sam --version              # SAM CLI
eksctl version             # EKS CLI
cdk --version              # AWS CDK
terraform --version        # Terraform
```

### Azure Tools
```bash
az --version               # Azure CLI
func --version             # Azure Functions
bicep --version            # Bicep
```

### GCP Tools
```bash
gcloud --version           # Google Cloud SDK
```

### Container Tools
```bash
docker --version           # Docker
podman --version           # Podman
kubectl version --client   # Kubernetes CLI
helm version               # Helm
k9s version                # k9s TUI
```

**Documentation**: [Included Tools](INCLUDED_TOOLS.md)

## Workspace Management

### Create Workspace
```bash
nubifer-workspace create --name "AWS Production" --provider aws --account prod
```

### Switch Workspace
```bash
nubifer-workspace switch aws-prod
```

### List Workspaces
```bash
nubifer-workspace list
```

## Credential Management

### Add Credentials
```bash
nubifer-creds add --provider aws --account prod-account
```

### List Credentials
```bash
nubifer-creds list
```

### Remove Credentials
```bash
nubifer-creds remove --provider aws --account prod-account
```

## Security Features

### Check BIOS Security
```bash
sudo /usr/local/bin/bios-security-confirm
```

### Enable Security Monitoring
```bash
sudo systemctl enable security-monitor
sudo systemctl start security-monitor
```

### Setup Recovery Key
```bash
sudo /usr/local/bin/recovery-key-setup
```

**Documentation**: [Recovery Key Guide](RECOVERY_KEY.md)

## Browser Configuration

### Firefox Containers
- **AWS Container** (Orange) - AWS Console
- **Azure Container** (Blue) - Azure Portal
- **GCP Container** (Red) - GCP Console
- **Personal Container** (Green) - Personal browsing

### Open Link in Container
Right-click link → "Open Link in New Container Tab"

### Security Features
- ✅ Tracking Protection (Strict)
- ✅ HTTPS-Only Mode
- ✅ DNS over HTTPS
- ✅ Fingerprinting Resistance
- ❌ Telemetry Disabled
- ❌ WebRTC Disabled

**Documentation**: [Browser Configuration](BROWSER_CONFIGURATION.md)

## IDE Quick Start

### VS Code
```bash
code .                     # Open current directory
code --install-extension <id>  # Install extension
```

**Installed Extensions**:
- AWS Toolkit, Azure Tools, Google Cloud Code
- Terraform, Docker, Kubernetes
- Python, Go, GitLens

### Neovim
```bash
nvim +PlugInstall +qall    # Install plugins
nvim                       # Open editor
```

**Key Bindings**:
- `Ctrl+n` - Toggle NERDTree
- `:Terraform fmt` - Format Terraform

### IntelliJ IDEA / PyCharm
```bash
idea .                     # Open project
pycharm .                  # Open project
```

**Recommended Plugins**: See `/tmp/intellij-recommended-plugins.txt`

**Documentation**: [IDE Plugins Guide](IDE_PLUGINS.md)

## Testing Tools

### Load Testing
```bash
k6 run script.js           # k6 load testing
locust -f locustfile.py    # Locust load testing
newman run collection.json # Postman/Newman API testing
```

### Browser Testing
```bash
pytest test_selenium.py    # Selenium tests
playwright test            # Playwright tests
cypress run                # Cypress tests
```

### Security Testing
```bash
trivy image <image>        # Container scanning
zap -cmd -quickurl <url>   # OWASP ZAP scanning
```

## Monitoring & Observability

### Prometheus
```bash
promtool check config prometheus.yml  # Validate config
```

### Grafana
```bash
grafana-cli plugins list   # List plugins
```

### Logs
```bash
logcli query '{job="app"}' # Query Loki logs
stern <pod-name>           # Kubernetes log tailing
```

## CI/CD Tools

### GitHub
```bash
gh repo list               # List repositories
gh pr list                 # List pull requests
gh workflow list           # List workflows
```

### GitLab
```bash
glab repo list             # List repositories
glab mr list               # List merge requests
glab ci status             # CI status
```

### ArgoCD
```bash
argocd app list            # List applications
argocd app sync <app>      # Sync application
```

### Flux
```bash
flux get sources           # Get sources
flux reconcile source git <name>  # Reconcile
```

## Database Clients

### PostgreSQL
```bash
psql -h localhost -U user -d database
```

### MySQL
```bash
mysql -h localhost -u user -p database
```

### MongoDB
```bash
mongosh "mongodb://localhost:27017"
```

### Redis
```bash
redis-cli
```

## Secrets Management

### HashiCorp Vault
```bash
vault login                # Login
vault kv get secret/data   # Get secret
vault kv put secret/data key=value  # Put secret
```

### SOPS
```bash
sops -e file.yaml > file.enc.yaml  # Encrypt
sops -d file.enc.yaml > file.yaml  # Decrypt
```

### age
```bash
age-keygen -o key.txt      # Generate key
age -r <recipient> -o file.enc file  # Encrypt
age -d -i key.txt file.enc # Decrypt
```

## Kubernetes

### Context Management
```bash
kubectl config get-contexts        # List contexts
kubectl config use-context <name>  # Switch context
```

### Resource Management
```bash
kubectl get pods                   # List pods
kubectl logs <pod>                 # View logs
kubectl exec -it <pod> -- /bin/bash  # Shell into pod
kubectl port-forward <pod> 8080:80 # Port forward
```

### Helm
```bash
helm repo add <name> <url>         # Add repository
helm search repo <keyword>         # Search charts
helm install <name> <chart>        # Install chart
helm list                          # List releases
```

### k9s
```bash
k9s                                # Launch k9s TUI
```

## Infrastructure as Code

### Terraform
```bash
terraform init                     # Initialize
terraform plan                     # Plan changes
terraform apply                    # Apply changes
terraform destroy                  # Destroy resources
```

### Pulumi
```bash
pulumi new                         # New project
pulumi up                          # Deploy
pulumi destroy                     # Destroy
```

### Ansible
```bash
ansible-playbook playbook.yml      # Run playbook
ansible-galaxy install <role>      # Install role
```

## Container Management

### Docker
```bash
docker build -t <image> .          # Build image
docker run <image>                 # Run container
docker ps                          # List containers
docker logs <container>            # View logs
docker exec -it <container> bash   # Shell into container
```

### Podman
```bash
podman build -t <image> .          # Build image
podman run <image>                 # Run container
podman ps                          # List containers
```

### Dive
```bash
dive <image>                       # Explore image layers
```

### Lazydocker
```bash
lazydocker                         # Docker TUI
```

## System Updates

### Update Cloud Tools
```bash
nubifer-tools update-cloud-tools   # Update cloud CLIs
nubifer-tools update-ides          # Update IDEs
nubifer-tools update-all           # Update everything
```

### System Updates
```bash
sudo apt update                    # Update package lists
sudo apt upgrade                   # Upgrade packages
```

## Documentation Access

### Local Documentation
- [Requirements](../.kiro/specs/custom-linux-distro/requirements.md)
- [Design](../.kiro/specs/custom-linux-distro/design.md)
- [Tasks](../.kiro/specs/custom-linux-distro/tasks.md)
- [IDE Plugins](IDE_PLUGINS.md)
- [Browser Configuration](BROWSER_CONFIGURATION.md)
- [Included Tools](INCLUDED_TOOLS.md)
- [Recovery Key](RECOVERY_KEY.md)

### Online Documentation
All tool documentation is bookmarked in Firefox under organized folders.

## Support

### NubiferOS
- **Documentation**: https://docs.nubiferos.org
- **GitHub**: https://github.com/nubiferos/nubiferos
- **Discord**: https://discord.gg/nubiferos
- **Issues**: https://github.com/nubiferos/nubiferos/issues

### Tool-Specific Support
See browser bookmarks for official documentation links for each tool.

---

**NubiferOS Version**: 1.0 (Nimbus)  
**Last Updated**: 2024-01-15
