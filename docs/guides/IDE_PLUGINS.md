# NubiferOS IDE Plugins and Extensions

This document describes the IDE plugins and extensions automatically configured for cloud development tools in NubiferOS.

## Overview

NubiferOS automatically installs and configures IDE plugins for the tools you have installed. When you install Terraform, for example, the appropriate Terraform plugin will be installed for your IDE of choice.

## Automatic Plugin Installation

Run the plugin installation script to automatically detect your IDEs and install relevant plugins:

```bash
sudo /usr/local/bin/install-ide-plugins
```

This script will:
1. Detect which IDEs you have installed
2. Install cloud development plugins for each IDE
3. Configure plugins with sensible defaults
4. Create configuration files for terminal-based editors

## Visual Studio Code

### Automatically Installed Extensions

#### Cloud Providers
- **AWS Toolkit** (`amazonwebservices.aws-toolkit-vscode`)
  - AWS service integration
  - Lambda function development
  - S3 browser
  - CloudFormation support
  
- **Azure Tools** (`ms-vscode.vscode-node-azure-pack`)
  - Azure service integration
  - Function deployment
  - Storage explorer
  
- **Google Cloud Code** (`googlecloudtools.cloudcode`)
  - GCP service integration
  - Cloud Run deployment
  - Cloud Functions support

#### Infrastructure as Code
- **Terraform** (`hashicorp.terraform`)
  - HCL syntax highlighting
  - Auto-completion
  - Format on save
  - Validation
  - Provider documentation
  
- **HCL** (`hashicorp.hcl`)
  - HashiCorp Configuration Language support
  
- **Pulumi** (`pulumi.pulumi-lsp-client`)
  - Pulumi language support
  - Resource documentation
  
- **Ansible** (`redhat.ansible`)
  - Playbook syntax
  - YAML validation
  - Module documentation

#### Containers & Kubernetes
- **Docker** (`ms-azuretools.vscode-docker`)
  - Dockerfile syntax
  - Image management
  - Container operations
  - Compose file support
  
- **Kubernetes** (`ms-kubernetes-tools.vscode-kubernetes-tools`)
  - Resource viewing
  - Pod logs
  - Port forwarding
  - Context switching

#### Languages
- **Python** (`ms-python.python`)
  - Python language support
  - Debugging
  - Linting
  
- **Pylance** (`ms-python.vscode-pylance`)
  - Fast Python language server
  
- **Go** (`golang.go`)
  - Go language support
  - Debugging
  
- **Java** (`redhat.java`)
  - Java language support

#### DevOps & CI/CD
- **GitHub Actions** (`github.vscode-github-actions`)
  - Workflow syntax
  - Action validation
  
- **GitLab Workflow** (`gitlab.gitlab-workflow`)
  - GitLab CI/CD support
  
- **Azure Pipelines** (`ms-azure-devops.azure-pipelines`)
  - Pipeline syntax

#### YAML & Configuration
- **YAML** (`redhat.vscode-yaml`)
  - YAML syntax
  - Schema validation
  
- **TOML** (`tamasfe.even-better-toml`)
  - TOML syntax

#### Git
- **GitLens** (`eamodio.gitlens`)
  - Enhanced Git integration
  - Blame annotations
  - History exploration
  
- **GitHub Pull Requests** (`github.vscode-pull-request-github`)
  - PR management in VS Code

#### Remote Development
- **Remote - SSH** (`ms-vscode-remote.remote-ssh`)
  - SSH remote development
  
- **Remote - Containers** (`ms-vscode-remote.remote-containers`)
  - Container-based development

#### Databases
- **SQLTools** (`mtxr.sqltools`)
  - Database client
  
- **MongoDB** (`mongodb.mongodb-vscode`)
  - MongoDB client

#### Security
- **Snyk** (`snyk-security.snyk-vulnerability-scanner`)
  - Vulnerability scanning

#### Productivity
- **Error Lens** (`usernamehw.errorlens`)
  - Inline error display
  
- **Code Spell Checker** (`streetsidesoftware.code-spell-checker`)
  - Spell checking
  
- **EditorConfig** (`editorconfig.editorconfig`)
  - Editor configuration

### Manual Installation

To install extensions manually:
```bash
code --install-extension <extension-id>
```

### Extension Settings

Extensions are configured with sensible defaults. To customize:
1. File → Preferences → Settings
2. Search for extension name
3. Modify settings

## VSCodium

VSCodium uses the same extensions as VS Code but from the Open VSX Registry.

### Installed Extensions
- Terraform
- Ansible
- Docker
- Kubernetes
- Python
- Go
- YAML
- GitLens

### Installation
```bash
codium --install-extension <extension-id>
```

## IntelliJ IDEA Community Edition

### Recommended Plugins

IntelliJ plugins are installed via the IDE's plugin manager.

#### Cloud Providers
- **AWS Toolkit** - AWS service integration
- **Azure Toolkit for IntelliJ** - Azure service integration
- **Google Cloud Code** - GCP service integration

#### Infrastructure as Code
- **Terraform and HCL** - Terraform support
- **HashiCorp Terraform / HCL language support**

#### Containers & Kubernetes
- **Docker** - Docker integration
- **Kubernetes** - K8s resource management

#### Languages
- **Python** - Python support (if not using PyCharm)
- **Go** - Go language support
- **Scala** - Scala support

#### DevOps
- **GitLab** - GitLab integration
- **GitHub** - GitHub integration

#### Databases
- **Database Tools and SQL** - Built-in database client

### Installation Steps
1. Open IntelliJ IDEA
2. File → Settings → Plugins
3. Search for plugin name
4. Click "Install"
5. Restart IDE

### Plugin List File
A complete list is available at: `/tmp/intellij-recommended-plugins.txt`

## PyCharm Community Edition

### Recommended Plugins

#### Cloud Providers
- **AWS Toolkit**
- **Azure Toolkit for IntelliJ**
- **Google Cloud Code**

#### Infrastructure as Code
- **Terraform and HCL**

#### Containers & Kubernetes
- **Docker**
- **Kubernetes**

#### DevOps
- **GitLab**
- **GitHub**

#### Databases
- **Database Tools and SQL**

#### Data Science
- **Jupyter** - Jupyter notebook support
- **R Language Support** - R language support

### Installation Steps
Same as IntelliJ IDEA

### Plugin List File
Available at: `/tmp/pycharm-recommended-plugins.txt`

## Neovim

### Plugin Manager

NubiferOS uses **vim-plug** for Neovim plugin management.

### Configuration File

Location: `~/.config/nvim/init.vim`

### Installed Plugins

#### LSP Support
- **nvim-lspconfig** - LSP client
- **mason.nvim** - LSP installer
- **mason-lspconfig.nvim** - LSP configuration

#### Autocompletion
- **nvim-cmp** - Completion engine
- **cmp-nvim-lsp** - LSP completion
- **cmp-buffer** - Buffer completion
- **cmp-path** - Path completion
- **LuaSnip** - Snippet engine

#### Cloud Tools
- **vim-terraform** - Terraform support
- **Dockerfile.vim** - Docker support
- **vim-kubernetes** - Kubernetes support
- **vim-yaml** - YAML support

#### Git
- **vim-fugitive** - Git integration
- **vim-gitgutter** - Git diff in gutter

#### File Management
- **NERDTree** - File explorer
- **fzf** - Fuzzy finder
- **fzf.vim** - FZF integration

#### UI
- **vim-airline** - Status line
- **gruvbox** - Color scheme

### Installation

Plugins are defined in `~/.config/nvim/init.vim`. To install:

```bash
nvim +PlugInstall +qall
```

### Usage

- **Ctrl+n** - Toggle NERDTree
- **:Terraform fmt** - Format Terraform file
- **:Git** - Git commands

### Terraform Settings

- Auto-align on save
- Format on save enabled

## Vim

### Plugin Manager

Uses **vim-plug** for plugin management.

### Configuration File

Location: `~/.vimrc`

### Installed Plugins

Same as Neovim but without LSP support:
- **vim-terraform** - Terraform support
- **Dockerfile.vim** - Docker support
- **vim-kubernetes** - Kubernetes support
- **vim-yaml** - YAML support
- **vim-fugitive** - Git integration
- **vim-gitgutter** - Git diff
- **NERDTree** - File explorer
- **fzf** - Fuzzy finder
- **vim-airline** - Status line
- **gruvbox** - Color scheme

### Installation

```bash
vim +PlugInstall +qall
```

### Usage

Same keybindings as Neovim

## Emacs

### Package Manager

Uses **MELPA** package repository with **use-package**.

### Configuration File

Location: `~/.emacs.d/init.el`

### Installed Packages

#### Cloud Tools
- **terraform-mode** - Terraform support
- **company-terraform** - Terraform completion
- **dockerfile-mode** - Docker support
- **kubernetes** - Kubernetes integration
- **ansible** - Ansible support

#### Languages
- **python-mode** - Python support
- **elpy** - Python development environment
- **go-mode** - Go support
- **json-mode** - JSON support
- **yaml-mode** - YAML support
- **markdown-mode** - Markdown support

#### Git
- **magit** - Git integration

#### Development Tools
- **company** - Auto-completion
- **flycheck** - Syntax checking
- **projectile** - Project management

#### UI
- **gruvbox-theme** - Color scheme

### Installation

Packages install automatically on first launch of Emacs.

To manually install:
1. Open Emacs
2. `M-x package-refresh-contents`
3. `M-x package-install RET <package-name>`

### Usage

- **C-c p** - Projectile commands
- **C-x g** - Magit status
- **M-x kubernetes-overview** - Kubernetes dashboard

### Terraform Settings

- Format on save enabled

## Kate

Kate is a lightweight text editor with basic syntax highlighting.

### Features
- Syntax highlighting for most languages
- Basic Git integration
- Project management

### Plugin Installation

Kate plugins are installed via:
1. Settings → Configure Kate
2. Plugins
3. Enable desired plugins

## Eclipse

Eclipse plugins are installed via the Eclipse Marketplace.

### Recommended Plugins
- **AWS Toolkit for Eclipse**
- **Docker Tooling**
- **Kubernetes**
- **Terraform Editor**

### Installation
1. Help → Eclipse Marketplace
2. Search for plugin
3. Install

## Plugin Features by Tool

### Terraform
- **Syntax highlighting** - HCL syntax coloring
- **Auto-completion** - Resource and variable completion
- **Format on save** - Automatic formatting
- **Validation** - Real-time error checking
- **Provider documentation** - Inline docs
- **Resource navigation** - Jump to definition

### Docker
- **Dockerfile syntax** - Syntax highlighting
- **Image management** - Build, run, stop images
- **Container operations** - Start, stop, logs
- **Compose support** - docker-compose.yml support
- **Registry integration** - Push/pull images

### Kubernetes
- **Resource viewing** - View pods, services, deployments
- **Pod logs** - Stream logs from pods
- **Port forwarding** - Forward ports to local machine
- **Context switching** - Switch between clusters
- **YAML validation** - Validate K8s manifests
- **Apply resources** - Deploy from IDE

### AWS Toolkit
- **Service explorer** - Browse AWS services
- **Lambda deployment** - Deploy functions
- **S3 browser** - Browse S3 buckets
- **CloudFormation** - Deploy stacks
- **Credentials** - Manage AWS profiles

### Azure Tools
- **Resource management** - Manage Azure resources
- **Function deployment** - Deploy Azure Functions
- **Storage explorer** - Browse storage accounts
- **App Service** - Deploy web apps

### Google Cloud Code
- **Project management** - Manage GCP projects
- **Cloud Run** - Deploy to Cloud Run
- **Cloud Functions** - Deploy functions
- **Kubernetes** - GKE integration

## Documentation Links

All IDE extensions have documentation links in the browser bookmarks under "IDE Extensions":

- VS Code Marketplace
- AWS Toolkit for VS Code
- Azure Tools for VS Code
- Google Cloud Code
- Terraform VS Code Extension
- Docker VS Code Extension
- Kubernetes VS Code Extension
- JetBrains Plugin Marketplace

## Troubleshooting

### VS Code Extensions Not Installing

1. Check internet connection
2. Try manual installation:
   ```bash
   code --install-extension <extension-id>
   ```
3. Check extension marketplace: https://marketplace.visualstudio.com/

### IntelliJ/PyCharm Plugins Not Working

1. File → Invalidate Caches / Restart
2. Check plugin compatibility with IDE version
3. Reinstall plugin

### Neovim/Vim Plugins Not Installing

1. Check vim-plug installation:
   ```bash
   ls ~/.local/share/nvim/site/autoload/plug.vim
   ```
2. Reinstall vim-plug:
   ```bash
   curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs \
     https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
   ```
3. Run `:PlugInstall` again

### Emacs Packages Not Installing

1. Refresh package list: `M-x package-refresh-contents`
2. Check MELPA connection
3. Manually install: `M-x package-install RET <package-name>`

## Updating Plugins

### VS Code
Extensions update automatically. To manually update:
1. Extensions view (Ctrl+Shift+X)
2. Click "Update" next to extension

### IntelliJ/PyCharm
1. File → Settings → Plugins
2. Click "Update" tab
3. Update all or individual plugins

### Neovim/Vim
```bash
nvim +PlugUpdate +qall
# or
vim +PlugUpdate +qall
```

### Emacs
```
M-x package-list-packages
U (mark upgrades)
x (execute)
```

## Custom Plugin Configuration

### VS Code Settings

Edit: `~/.config/Code/User/settings.json`

Example:
```json
{
  "terraform.languageServer.enable": true,
  "terraform.format.enable": true,
  "docker.showStartPage": false,
  "kubernetes.useKubeconfig": true
}
```

### Neovim Configuration

Edit: `~/.config/nvim/init.vim`

Add custom plugin configurations after the `plug#end()` call.

### Emacs Configuration

Edit: `~/.emacs.d/init.el`

Add custom configurations after package declarations.

## Support

### VS Code Extensions
- VS Code Docs: https://code.visualstudio.com/docs/editor/extension-marketplace

### IntelliJ/PyCharm Plugins
- JetBrains Docs: https://www.jetbrains.com/help/idea/managing-plugins.html

### Vim/Neovim Plugins
- vim-plug: https://github.com/junegunn/vim-plug

### Emacs Packages
- MELPA: https://melpa.org/

### NubiferOS Issues
- GitHub: https://github.com/nubiferos/nubiferos/issues
- Discord: https://discord.gg/nubiferos

---

**Last Updated**: 2024-01-15  
**NubiferOS Version**: 1.0 (Nimbus)
