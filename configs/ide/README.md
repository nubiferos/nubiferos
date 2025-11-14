# IDE Plugin Configuration

This directory contains scripts and configurations for automatically installing IDE plugins for cloud development tools.

## Quick Start

Install IDE plugins for all detected IDEs:

```bash
sudo /usr/local/bin/install-ide-plugins
```

This will:
1. Detect which IDEs you have installed (VS Code, IntelliJ, PyCharm, Vim, Neovim, Emacs, etc.)
2. Install appropriate plugins for cloud tools (Terraform, Docker, Kubernetes, AWS, Azure, GCP)
3. Configure plugins with sensible defaults
4. Create configuration files for terminal-based editors

## Supported IDEs

### Visual Studio Code / VSCodium
- **Plugins**: AWS Toolkit, Azure Tools, Google Cloud Code, Terraform, Docker, Kubernetes, Python, Go, GitLens
- **Installation**: Automatic via `code --install-extension`
- **Configuration**: `~/.config/Code/User/settings.json`

### IntelliJ IDEA / PyCharm
- **Plugins**: AWS Toolkit, Azure Toolkit, Terraform, Docker, Kubernetes
- **Installation**: Manual via IDE plugin manager (recommendation file created)
- **Recommendation File**: `/tmp/intellij-recommended-plugins.txt` or `/tmp/pycharm-recommended-plugins.txt`

### Neovim
- **Plugins**: LSP support, vim-terraform, Dockerfile.vim, vim-kubernetes, vim-yaml, NERDTree, fzf
- **Plugin Manager**: vim-plug
- **Configuration**: `~/.config/nvim/init.vim` (auto-generated)
- **Installation**: Run `nvim +PlugInstall +qall` after script execution

### Vim
- **Plugins**: vim-terraform, Dockerfile.vim, vim-kubernetes, vim-yaml, NERDTree, fzf
- **Plugin Manager**: vim-plug
- **Configuration**: `~/.vimrc` (auto-generated)
- **Installation**: Run `vim +PlugInstall +qall` after script execution

### Emacs
- **Packages**: terraform-mode, dockerfile-mode, kubernetes, ansible, python-mode, go-mode, magit
- **Package Manager**: MELPA with use-package
- **Configuration**: `~/.emacs.d/init.el` (auto-generated)
- **Installation**: Automatic on first Emacs launch

## Plugin Features by Tool

### Terraform
- Syntax highlighting and auto-completion
- Format on save
- Validation and error checking
- Provider documentation
- Resource navigation

### Docker
- Dockerfile syntax highlighting
- Image and container management
- Docker Compose support
- Registry integration

### Kubernetes
- Resource viewing and management
- Pod logs streaming
- Port forwarding
- Context switching
- YAML validation

### AWS Toolkit
- Service explorer
- Lambda function deployment
- S3 browser
- CloudFormation support

### Azure Tools
- Resource management
- Function deployment
- Storage explorer

### Google Cloud Code
- Project management
- Cloud Run deployment
- Cloud Functions support
- GKE integration

## Manual Plugin Installation

### VS Code
```bash
code --install-extension <extension-id>
```

### IntelliJ/PyCharm
1. File → Settings → Plugins
2. Search and install

### Vim/Neovim
Add to `.vimrc` or `init.vim`:
```vim
Plug 'hashivim/vim-terraform'
```
Then run `:PlugInstall`

### Emacs
Add to `init.el`:
```elisp
(use-package terraform-mode)
```
Then restart Emacs

## Documentation

Full documentation: [docs/IDE_PLUGINS.md](../../docs/IDE_PLUGINS.md)

## Troubleshooting

### Plugins Not Installing
1. Check internet connection
2. Verify IDE is installed: `which code` or `which nvim`
3. Check logs in `/tmp/ide-plugin-install.log`

### VS Code Extensions Failing
```bash
# Try manual installation
code --install-extension hashicorp.terraform
```

### Vim/Neovim Plugins Not Loading
```bash
# Reinstall vim-plug
curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs \
  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

# Then run
nvim +PlugInstall +qall
```

### Emacs Packages Not Installing
```
M-x package-refresh-contents
M-x package-install RET terraform-mode
```

## Files

- `install-ide-plugins.sh` - Main installation script
- `README.md` - This file

## Related Documentation

- [IDE Plugins Guide](../../docs/IDE_PLUGINS.md) - Complete plugin documentation
- [Browser Configuration](../../docs/BROWSER_CONFIGURATION.md) - Documentation bookmarks
- [Included Tools](../../docs/INCLUDED_TOOLS.md) - All installed tools

---

**NubiferOS Version**: 1.0 (Nimbus)
