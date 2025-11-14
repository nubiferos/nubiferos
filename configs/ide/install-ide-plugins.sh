#!/bin/bash
# Install IDE plugins for cloud development tools
# Part of NubiferOS build system

set -e

# Load brand configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../brand/load-brand.sh"
source "${SCRIPT_DIR}/../../build/config.sh"

init_config

log "INFO" "Starting IDE plugin installation"

# Detect installed IDEs
detect_ides() {
    INSTALLED_IDES=()
    
    command -v code &> /dev/null && INSTALLED_IDES+=("vscode")
    command -v codium &> /dev/null && INSTALLED_IDES+=("vscodium")
    command -v idea &> /dev/null && INSTALLED_IDES+=("intellij")
    command -v pycharm &> /dev/null && INSTALLED_IDES+=("pycharm")
    command -v nvim &> /dev/null && INSTALLED_IDES+=("neovim")
    command -v vim &> /dev/null && INSTALLED_IDES+=("vim")
    command -v emacs &> /dev/null && INSTALLED_IDES+=("emacs")
    
    log "INFO" "Detected IDEs: ${INSTALLED_IDES[*]}"
}

# Install VS Code extensions
install_vscode_extensions() {
    log "INFO" "=========================================="
    log "INFO" "Installing VS Code Extensions"
    log "INFO" "=========================================="
    
    local extensions=(
        # Cloud Providers
        "amazonwebservices.aws-toolkit-vscode"
        "ms-vscode.vscode-node-azure-pack"
        "googlecloudtools.cloudcode"
        
        # Infrastructure as Code
        "hashicorp.terraform"
        "hashicorp.hcl"
        "pulumi.pulumi-lsp-client"
        "redhat.ansible"
        
        # Containers & Kubernetes
        "ms-azuretools.vscode-docker"
        "ms-kubernetes-tools.vscode-kubernetes-tools"
        "googlecloudtools.cloudcode"
        
        # Languages
        "ms-python.python"
        "ms-python.vscode-pylance"
        "golang.go"
        "ms-vscode.cpptools"
        "redhat.java"
        
        # DevOps & CI/CD
        "github.vscode-github-actions"
        "gitlab.gitlab-workflow"
        "ms-azure-devops.azure-pipelines"
        
        # YAML & JSON
        "redhat.vscode-yaml"
        "tamasfe.even-better-toml"
        
        # Git
        "eamodio.gitlens"
        "github.vscode-pull-request-github"
        
        # Remote Development
        "ms-vscode-remote.remote-ssh"
        "ms-vscode-remote.remote-containers"
        
        # Databases
        "mtxr.sqltools"
        "mongodb.mongodb-vscode"
        
        # Testing
        "hbenl.vscode-test-explorer"
        
        # Security
        "snyk-security.snyk-vulnerability-scanner"
        
        # Productivity
        "usernamehw.errorlens"
        "streetsidesoftware.code-spell-checker"
        "editorconfig.editorconfig"
    )
    
    for ext in "${extensions[@]}"; do
        log "INFO" "Installing ${ext}..."
        code --install-extension "${ext}" --force 2>/dev/null || log "WARN" "Failed to install ${ext}"
    done
    
    log "INFO" "✓ VS Code extensions installed"
}

# Install VSCodium extensions
install_vscodium_extensions() {
    log "INFO" "=========================================="
    log "INFO" "Installing VSCodium Extensions"
    log "INFO" "=========================================="
    
    # VSCodium uses same extensions as VS Code but from open-vsx.org
    local extensions=(
        "hashicorp.terraform"
        "redhat.ansible"
        "ms-azuretools.vscode-docker"
        "ms-kubernetes-tools.vscode-kubernetes-tools"
        "ms-python.python"
        "golang.go"
        "redhat.vscode-yaml"
        "eamodio.gitlens"
    )
    
    for ext in "${extensions[@]}"; do
        log "INFO" "Installing ${ext}..."
        codium --install-extension "${ext}" --force 2>/dev/null || log "WARN" "Failed to install ${ext}"
    done
    
    log "INFO" "✓ VSCodium extensions installed"
}

# Configure IntelliJ IDEA plugins
install_intellij_plugins() {
    log "INFO" "=========================================="
    log "INFO" "Configuring IntelliJ IDEA Plugins"
    log "INFO" "=========================================="
    
    # IntelliJ plugins are installed via the IDE's plugin manager
    # We'll create a plugins list file for user reference
    
    cat > /tmp/intellij-recommended-plugins.txt << 'EOF'
# Recommended IntelliJ IDEA Plugins for Cloud Development

## Cloud Providers
- AWS Toolkit
- Azure Toolkit for IntelliJ
- Google Cloud Code

## Infrastructure as Code
- Terraform and HCL
- HashiCorp Terraform / HCL language support

## Containers & Kubernetes
- Docker
- Kubernetes

## Languages
- Python
- Go
- Scala

## DevOps
- GitLab
- GitHub

## Databases
- Database Tools and SQL

## Installation:
1. Open IntelliJ IDEA
2. Go to File > Settings > Plugins
3. Search for and install the plugins listed above
EOF
    
    log "INFO" "✓ IntelliJ plugin list created at /tmp/intellij-recommended-plugins.txt"
}

# Configure PyCharm plugins
install_pycharm_plugins() {
    log "INFO" "=========================================="
    log "INFO" "Configuring PyCharm Plugins"
    log "INFO" "=========================================="
    
    cat > /tmp/pycharm-recommended-plugins.txt << 'EOF'
# Recommended PyCharm Plugins for Cloud Development

## Cloud Providers
- AWS Toolkit
- Azure Toolkit for IntelliJ
- Google Cloud Code

## Infrastructure as Code
- Terraform and HCL

## Containers & Kubernetes
- Docker
- Kubernetes

## DevOps
- GitLab
- GitHub

## Databases
- Database Tools and SQL

## Data Science
- Jupyter
- R Language Support

## Installation:
1. Open PyCharm
2. Go to File > Settings > Plugins
3. Search for and install the plugins listed above
EOF
    
    log "INFO" "✓ PyCharm plugin list created at /tmp/pycharm-recommended-plugins.txt"
}

# Configure Neovim plugins
install_neovim_plugins() {
    log "INFO" "=========================================="
    log "INFO" "Configuring Neovim Plugins"
    log "INFO" "=========================================="
    
    # Create init.vim with plugin recommendations
    mkdir -p ~/.config/nvim
    
    cat > ~/.config/nvim/init.vim << 'EOF'
" NubiferOS Neovim Configuration for Cloud Development

" Install vim-plug if not already installed
if empty(glob('~/.local/share/nvim/site/autoload/plug.vim'))
  silent !curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs
    \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

call plug#begin('~/.local/share/nvim/plugged')

" LSP Support
Plug 'neovim/nvim-lspconfig'
Plug 'williamboman/mason.nvim'
Plug 'williamboman/mason-lspconfig.nvim'

" Autocompletion
Plug 'hrsh7th/nvim-cmp'
Plug 'hrsh7th/cmp-nvim-lsp'
Plug 'hrsh7th/cmp-buffer'
Plug 'hrsh7th/cmp-path'
Plug 'L3MON4D3/LuaSnip'

" Terraform
Plug 'hashivim/vim-terraform'

" Docker
Plug 'ekalinin/Dockerfile.vim'

" Kubernetes
Plug 'andrewstuart/vim-kubernetes'

" YAML
Plug 'stephpy/vim-yaml'

" Git
Plug 'tpope/vim-fugitive'
Plug 'airblade/vim-gitgutter'

" File Explorer
Plug 'preservim/nerdtree'

" Fuzzy Finder
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'

" Status Line
Plug 'vim-airline/vim-airline'

" Color Schemes
Plug 'morhetz/gruvbox'

call plug#end()

" Basic Settings
set number
set relativenumber
set expandtab
set tabstop=2
set shiftwidth=2
set smartindent
set termguicolors
colorscheme gruvbox

" Terraform settings
let g:terraform_align=1
let g:terraform_fmt_on_save=1

" NERDTree
nnoremap <C-n> :NERDTreeToggle<CR>

" Run :PlugInstall to install all plugins
EOF
    
    log "INFO" "✓ Neovim configuration created at ~/.config/nvim/init.vim"
    log "INFO" "  Run 'nvim +PlugInstall +qall' to install plugins"
}

# Configure Vim plugins
install_vim_plugins() {
    log "INFO" "=========================================="
    log "INFO" "Configuring Vim Plugins"
    log "INFO" "=========================================="
    
    cat > ~/.vimrc << 'EOF'
" NubiferOS Vim Configuration for Cloud Development

" Install vim-plug if not already installed
if empty(glob('~/.vim/autoload/plug.vim'))
  silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
    \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

call plug#begin('~/.vim/plugged')

" Terraform
Plug 'hashivim/vim-terraform'

" Docker
Plug 'ekalinin/Dockerfile.vim'

" Kubernetes
Plug 'andrewstuart/vim-kubernetes'

" YAML
Plug 'stephpy/vim-yaml'

" Git
Plug 'tpope/vim-fugitive'
Plug 'airblade/vim-gitgutter'

" File Explorer
Plug 'preservim/nerdtree'

" Fuzzy Finder
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'

" Status Line
Plug 'vim-airline/vim-airline'

" Color Schemes
Plug 'morhetz/gruvbox'

call plug#end()

" Basic Settings
set number
set expandtab
set tabstop=2
set shiftwidth=2
set smartindent
syntax on
colorscheme gruvbox

" Terraform settings
let g:terraform_align=1
let g:terraform_fmt_on_save=1

" NERDTree
nnoremap <C-n> :NERDTreeToggle<CR>

" Run :PlugInstall to install all plugins
EOF
    
    log "INFO" "✓ Vim configuration created at ~/.vimrc"
    log "INFO" "  Run 'vim +PlugInstall +qall' to install plugins"
}

# Configure Emacs packages
install_emacs_packages() {
    log "INFO" "=========================================="
    log "INFO" "Configuring Emacs Packages"
    log "INFO" "=========================================="
    
    mkdir -p ~/.emacs.d
    
    cat > ~/.emacs.d/init.el << 'EOF'
;; NubiferOS Emacs Configuration for Cloud Development

;; Package Management
(require 'package)
(setq package-archives '(("melpa" . "https://melpa.org/packages/")
                         ("gnu" . "https://elpa.gnu.org/packages/")))
(package-initialize)

;; Install use-package
(unless (package-installed-p 'use-package)
  (package-refresh-contents)
  (package-install 'use-package))

(require 'use-package)
(setq use-package-always-ensure t)

;; Terraform
(use-package terraform-mode)
(use-package company-terraform
  :config
  (company-terraform-init))

;; Docker
(use-package dockerfile-mode)

;; Kubernetes
(use-package kubernetes
  :commands (kubernetes-overview))

;; YAML
(use-package yaml-mode)

;; Git
(use-package magit)

;; Python
(use-package python-mode)
(use-package elpy
  :init
  (elpy-enable))

;; Go
(use-package go-mode)

;; Ansible
(use-package ansible)

;; JSON
(use-package json-mode)

;; Markdown
(use-package markdown-mode)

;; Auto-completion
(use-package company
  :config
  (global-company-mode t))

;; Syntax checking
(use-package flycheck
  :init (global-flycheck-mode))

;; Project management
(use-package projectile
  :config
  (projectile-mode +1)
  (define-key projectile-mode-map (kbd "C-c p") 'projectile-command-map))

;; Theme
(use-package gruvbox-theme
  :config
  (load-theme 'gruvbox-dark-hard t))

;; Basic Settings
(setq-default indent-tabs-mode nil)
(setq-default tab-width 2)
(global-display-line-numbers-mode)
(tool-bar-mode -1)
(menu-bar-mode -1)
(scroll-bar-mode -1)

;; Terraform format on save
(add-hook 'terraform-mode-hook
          (lambda ()
            (add-hook 'before-save-hook 'terraform-format-buffer nil t)))
EOF
    
    log "INFO" "✓ Emacs configuration created at ~/.emacs.d/init.el"
    log "INFO" "  Packages will be installed automatically on first launch"
}

# Create IDE plugin documentation
create_plugin_documentation() {
    log "INFO" "Creating IDE plugin documentation..."
    
    cat > /tmp/ide-plugins-guide.md << 'EOF'
# IDE Plugins for Cloud Development

This guide lists recommended plugins for each IDE included in NubiferOS.

## Visual Studio Code

### Cloud Providers
- **AWS Toolkit** - AWS service integration
- **Azure Tools** - Azure service integration
- **Google Cloud Code** - GCP service integration

### Infrastructure as Code
- **Terraform** - Terraform/HCL syntax and validation
- **Pulumi** - Pulumi language support
- **Ansible** - Ansible playbook support

### Containers & Kubernetes
- **Docker** - Docker file support and container management
- **Kubernetes** - K8s resource management

### Languages
- **Python** - Python language support
- **Go** - Go language support
- **Java** - Java language support

### DevOps
- **GitLens** - Enhanced Git integration
- **GitHub Actions** - GitHub workflow support
- **GitLab Workflow** - GitLab CI/CD support

## IntelliJ IDEA / PyCharm

### Installation
1. Open IDE
2. File > Settings > Plugins
3. Search and install:
   - AWS Toolkit
   - Azure Toolkit
   - Terraform and HCL
   - Docker
   - Kubernetes

## Vim / Neovim

### Plugins (via vim-plug)
- **vim-terraform** - Terraform support
- **Dockerfile.vim** - Docker support
- **vim-kubernetes** - Kubernetes support
- **vim-fugitive** - Git integration

### Installation
Run: `vim +PlugInstall +qall` or `nvim +PlugInstall +qall`

## Emacs

### Packages (via MELPA)
- **terraform-mode** - Terraform support
- **dockerfile-mode** - Docker support
- **kubernetes** - Kubernetes support
- **magit** - Git integration

### Installation
Packages install automatically on first launch

## Plugin Features by Tool

### Terraform
- Syntax highlighting
- Auto-completion
- Format on save
- Validation
- Provider documentation

### Docker
- Dockerfile syntax
- Image management
- Container operations
- Compose file support

### Kubernetes
- Resource viewing
- Pod logs
- Port forwarding
- Context switching

### AWS
- Service explorer
- Lambda deployment
- S3 browser
- CloudFormation support

### Azure
- Resource management
- Function deployment
- Storage explorer

### GCP
- Project management
- Cloud Run deployment
- Cloud Functions support

## Auto-Installation

Run the plugin installation script:
```bash
sudo /usr/local/bin/install-ide-plugins
```

This will detect your installed IDEs and configure appropriate plugins.

## Manual Installation

### VS Code
```bash
code --install-extension <extension-id>
```

### IntelliJ/PyCharm
File > Settings > Plugins > Marketplace

### Vim/Neovim
Add to .vimrc/init.vim and run `:PlugInstall`

### Emacs
Add to init.el and restart Emacs

## Documentation Links

See browser bookmarks for official documentation for each tool and plugin.
EOF
    
    log "INFO" "✓ Plugin documentation created at /tmp/ide-plugins-guide.md"
}

# Main execution
main() {
    log "INFO" "=========================================="
    log "INFO" "IDE Plugin Installation"
    log "INFO" "=========================================="
    
    detect_ides
    
    for ide in "${INSTALLED_IDES[@]}"; do
        case $ide in
            vscode)
                install_vscode_extensions
                ;;
            vscodium)
                install_vscodium_extensions
                ;;
            intellij)
                install_intellij_plugins
                ;;
            pycharm)
                install_pycharm_plugins
                ;;
            neovim)
                install_neovim_plugins
                ;;
            vim)
                install_vim_plugins
                ;;
            emacs)
                install_emacs_packages
                ;;
        esac
    done
    
    create_plugin_documentation
    
    log "INFO" "=========================================="
    log "INFO" "IDE plugin installation complete!"
    log "INFO" "=========================================="
    log "INFO" "Documentation: /tmp/ide-plugins-guide.md"
}

main "$@"
