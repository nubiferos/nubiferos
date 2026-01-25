# Implementation Plan

## 🔴 PRIORITY: D-Bus Services Integration (Blocking workspace/credential features)

The following components are built but NOT functional because D-Bus services aren't installed:
- Context Manager D-Bus service (workspace switching, context indicator)
- Credential Manager D-Bus service (credential injection to CLI wrappers)
- CLI wrappers (depend on D-Bus for credentials)
- GNOME Shell context indicator (depends on D-Bus for workspace info)

**Next steps to complete:**
1. Install Context Manager D-Bus service and systemd unit
2. Install Credential Manager D-Bus service and systemd unit  
3. Enable CLI wrapper symlinks
4. Test credential_process helper as alternative to D-Bus for AWS CLI
5. Configure GPG agent caching and session cleanup

---

- [x] 1. Set up build system and project structure
  - Create directory structure for NubiferOS project (build/, components/, configs/, installer/)
  - Create build configuration file with base distro settings, versions, and component paths
  - Set up version control and documentation structure
  - _Requirements: 11.1, 11.2_

- [x] 2. Create base ISO build system
  - [x] 2.1 Set up Debian base extraction
    - Write script to download Debian 12 (Bookworm) base ISO and verify GPG signature
    - Implement ISO extraction and filesystem customization using debootstrap
    - Enable Debian security repository for automatic security updates
    - _Requirements: 1.1, 1.3, 11.3, 12.1_

  - [x] 2.2 Implement cloud tools installation script
    - Create install-cloud-tools.sh script that installs AWS CLI, Azure CLI, gcloud SDK
    - Add installation for IaC tools (Terraform, Pulumi, Ansible)
    - Add container tools (Docker, kubectl, Helm, k9s)
    - Add AWS-specific tools (SAM CLI, eksctl, CDK, Session Manager plugin, NoSQL Workbench)
    - Verify all tools install correctly and are in PATH
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6_

  - [x] 2.3 Apply security hardening
    - Install and configure AppArmor with profiles for NubiferOS services
    - Configure kernel hardening parameters in /etc/sysctl.conf (enable ASLR, disable IPv6 if not needed, etc.)
    - Install and configure fail2ban for intrusion prevention
    - Set up unattended-upgrades for automatic security patches
    - Configure ufw firewall with deny-by-default policy
    - Disable unnecessary systemd services
    - Install auditd for system auditing
    - _Requirements: 11.3, 11.4, 11.5, 11.6, 11.7_

  - [x] 2.4 Configure desktop environment
    - Install and configure GNOME desktop environment
    - Set up virtual desktop support with at least 4 workspaces
    - Configure default theme and NubiferOS branding
    - Enable GNOME Keyring with encryption
    - _Requirements: 1.2, 11.2_

  - [x] 2.5 Create ISO generation script
    - Write build-iso.sh that orchestrates the full build process
    - Implement ISO creation using xorriso or grub-mkrescue
    - Add checksum generation (SHA256) and GPG signing for the final ISO
    - _Requirements: 1.3, 12.5_

- [x] 3. Implement Credential Manager service
  - [x] 3.1 Create credential storage backend
    - Implement Python service with pass (password-store) backend
    - Add SQLite database for credential metadata (provider, account, auth type)
    - Use pass for encrypted credential storage with GPG
    - Implement pass store structure: nubiferos/credentials/{provider}/{account-id}
    - _Requirements: 3.1, 3.3, 11.2_

  - [x] 3.2 Implement D-Bus interface
    - Define D-Bus service interface (AddCredential, GetCredential, ListAccounts, DeleteCredential)
    - Implement D-Bus service registration and method handlers
    - _Requirements: 3.4_
    - _Note: Code exists but service not installed/running - needs systemd integration_

  - [x] 3.3 Add access key authentication support
    - Implement storage and retrieval of AWS access keys
    - Implement storage and retrieval of Azure service principal credentials
    - Implement storage and retrieval of GCP service account keys
    - _Requirements: 3.2_

  - [x] 3.4 Create CLI tool for credential management
    - Implement nubifer-creds command-line tool for adding/listing/removing credentials
    - Add interactive prompts for credential input
    - _Requirements: 3.1, 3.2_

  - [ ] 3.5 Create systemd service definition
    - Write systemd service file for credential manager
    - Configure service to start on boot
    - Install D-Bus service file for auto-activation
    - _Requirements: 3.1_
    - _Status: NOT DONE - D-Bus service not installed, CLI works standalone_

  - [ ] 3.6 Implement credential_process helper for AWS CLI
    - Create nubifer-aws-credential-helper for AWS CLI credential_process
    - Integrate with pass to retrieve credentials on-demand
    - Configure GPG agent caching for performance
    - _Requirements: 3.4_
    - _Status: Helper created, needs testing and integration_

- [x] 4. Implement Context Manager service
  - [x] 4.1 Create workspace management backend
    - Implement Python service for workspace CRUD operations
    - Create SQLite database for workspace configurations
    - Implement workspace data model (provider, account, region, credentials, read_only)
    - _Requirements: 4.1, 4.2_

  - [x] 4.2 Implement D-Bus interface
    - Define D-Bus interface (CreateWorkspace, SwitchWorkspace, GetCurrentWorkspace, ListWorkspaces)
    - Implement D-Bus service registration and method handlers
    - Add WorkspaceSwitched signal
    - _Requirements: 4.3_
    - _Note: Code exists but service not installed/running - needs systemd integration_

  - [x] 4.3 Implement virtual desktop integration
    - Integrate with GNOME virtual desktop API to switch workspaces
    - Map each NubiferOS workspace to a GNOME virtual desktop
    - _Requirements: 4.1, 4.2_
    - _Note: Basic implementation done, full GNOME integration deferred_

  - [x] 4.4 Implement environment variable injection
    - Create mechanism to set environment variables per workspace (AWS_PROFILE, AWS_REGION, etc.)
    - Implement environment isolation between workspaces
    - Create shell integration script for /etc/profile.d/
    - _Requirements: 4.4, 4.5, 4.6_

  - [x] 4.5 Implement read-only mode
    - Add read_only flag to workspace configuration
    - Create mechanism to block write operations when read-only mode is active
    - _Requirements: 8.1, 8.2, 8.4_
    - _Note: Flag implemented, write operation blocking deferred to CLI wrapper integration_

  - [x] 4.6 Create CLI tool for workspace management
    - Implement nubifer-workspace command-line tool
    - Add commands for create, switch, list, delete workspaces
    - Add set-readonly command
    - _Requirements: 4.1, 4.2, 4.3_

  - [ ] 4.7 Create systemd service definition
    - Write systemd service file for context manager
    - Configure service dependencies (requires credential manager)
    - Install D-Bus service file for auto-activation
    - _Requirements: 4.1_
    - _Status: NOT DONE - D-Bus service not installed, CLI works standalone_

- [x] 5. Implement Context Indicator UI
  - [x] 5.1 Create GNOME Shell extension
    - Implement GNOME Shell extension skeleton with panel indicator
    - Subscribe to D-Bus signals from Context Manager for workspace changes
    - Display current provider, account, region, and read-only status
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.6_
    - _Note: Extension installed but shows "No Workspace" until D-Bus service runs_

  - [x] 5.2 Implement visual theming
    - Add color coding for different cloud providers (AWS orange, Azure blue, GCP red)
    - Implement distinct visual indicators for read-only vs read-write mode
    - _Requirements: 5.4, 5.5_

  - [x] 5.3 Add workspace switcher menu
    - Implement dropdown menu showing all workspaces
    - Add click handlers to switch workspaces from the indicator
    - _Requirements: 4.3, 5.5_
    - _Note: Menu implemented but requires D-Bus service to populate_

  - [x] 5.4 Implement terminal prompt integration
    - Create shell integration script that modifies PS1 with workspace context
    - Add to /etc/profile.d/ for automatic loading
    - _Requirements: 5.6_

- [ ] 6. Implement CLI wrapper scripts
  - [x] 6.1 Create credential injection wrappers
    - Write wrapper scripts for aws, az, gcloud that inject credentials from Credential Manager
    - Place wrappers in /usr/local/bin/ to override default CLI tools
    - Implement secure credential injection without environment variable exposure
    - _Requirements: 3.4_
    - _Note: Wrappers exist but NOT symlinked - credential injection via D-Bus not working_

  - [x] 6.2 Implement read-only mode enforcement
    - Add logic to wrappers to block write operations when workspace is in read-only mode
    - Show clear error messages when write operations are blocked
    - Pattern matching for AWS, Azure, GCP write operations
    - Command-based blocking for Terraform and Kubectl
    - _Requirements: 8.2, 8.3_

  - [ ] 6.3 Add workspace context to CLI commands
    - Ensure all CLI commands use the current workspace's credentials and configuration
    - Check for active workspace before execution
    - Integrate with Context Manager via D-Bus
    - _Requirements: 4.3, 4.4_
    - _Status: NOT WORKING - D-Bus services not running, wrappers not symlinked_

  - [ ] 6.4 Enable CLI wrappers during installation
    - Create symlinks from /usr/local/bin/aws -> wrapper during post-install
    - Add option to enable/disable wrappers
    - _Status: NOT DONE - symlinks not created_

- [x] 7. Implement First-Boot Setup Experience
  - [x] 7.1 Create first-boot wizard application
    - Implement GTK4 wizard with multi-page flow
    - Add GPG key generation guidance
    - Add pass initialization guidance
    - Add workspace creation instructions
    - Add credential setup instructions
    - _Requirements: 14.1, 14.2, 14.3, 14.4, 14.5_

  - [x] 7.2 Implement installer environment detection
    - Add detection for live boot indicators
    - Prevent wizard from launching during installation
    - _Requirements: 14.6_

  - [x] 7.3 Create desktop integration
    - Create desktop shortcut for re-running setup
    - Create HTML documentation files
    - Install documentation to /usr/share/nubifer/docs/
    - _Requirements: 14.7, 14.8_

  - [x] 7.4 Integrate into build system
    - Update install-first-boot-wizard.sh
    - Add desktop files to /etc/skel/Desktop/
    - Configure autostart for first login
    - _Requirements: 14.1_

- [ ] 8. Implement basic Resource Viewer application
  - [ ] 8.1 Set up application framework
    - Create Electron or Tauri application skeleton
    - Set up React or Vue frontend with basic routing
    - Create FastAPI or Gin backend with REST API
    - _Requirements: 7.1_

  - [ ] 8.2 Implement resource indexer
    - Create Python module to fetch resources from AWS using boto3
    - Implement resource fetching for EC2, S3, Lambda, RDS, VPC
    - Store resources in SQLite database with schema (id, provider, account, service, type, properties)
    - _Requirements: 6.1, 6.2, 6.5_

  - [ ] 8.3 Create resource browser UI
    - Implement tree view of resources grouped by service
    - Add resource detail panel showing properties
    - Implement search and filter functionality
    - _Requirements: 7.2, 7.3, 7.4_

  - [ ] 8.4 Implement sync functionality
    - Add manual sync button to refresh resources from cloud
    - Show last sync timestamp
    - Display sync progress indicator
    - _Requirements: 6.1, 6.5_

  - [ ] 8.5 Add offline browsing support
    - Ensure UI works with cached data when offline
    - Show indicator when viewing cached data
    - _Requirements: 6.3_

  - [ ] 8.6 Package as desktop application
    - Create .desktop file for application launcher
    - Add NubiferOS branding and icon
    - _Requirements: 7.1_

- [x] 9. Implement installer system
  - [x] 9.1 Configure Calamares installer
    - Install Calamares installer framework
    - Create NubiferOS branding module (logo, colors, welcome text with security emphasis)
    - Configure installation modules (partition with mandatory LUKS encryption, users, locale)
    - Add security warning about importance of strong passphrase
    - _Requirements: 11.1, 12.3, 12.4, 12.6_
    - _Note: Implemented and working_

  - [x] 9.2 Create post-install script
    - Write script to enable NubiferOS systemd services
    - Install and enable GNOME Shell extension
    - Create default workspace
    - Configure shell integration
    - Set NubiferOS wallpaper and theme
    - Verify all security features are enabled (AppArmor, firewall, automatic updates)
    - _Requirements: 12.3_
    - _Note: Implemented via Calamares shellprocess modules_

  - [x] 9.3 Integrate installer into ISO
    - Configure ISO to boot into Calamares installer
    - ~~Add live mode option for trying before installing~~ (Removed for security - no live CD)
    - Configure secure boot support
    - _Requirements: 1.3, 11.4, 12.3_
    - _Note: Live CD removed to prevent encryption bypass_

  - [x] 9.4 Lock down installer environment
    - Disable Cancel button in Calamares (disable-cancel: true)
    - Hide GNOME panel during installation (installer-mode extension)
    - Disable hot corners and Activities overview
    - Maximize Calamares window on startup
    - Lock dconf settings to prevent user changes
    - _Requirements: 12.6_
    - _Note: Implemented in configure-installer-autostart.sh_

- [ ] 10. Implement AI Assistant Framework
  - [ ] 10.1 Create AI Assistant service architecture
    - Implement Python service with plugin architecture for LLM providers
    - Create D-Bus interface for AI Assistant (IsEnabled, Enable, Disable, Query, GetConfig)
    - Implement configuration file parser for ai-config.yaml
    - _Requirements: 12.1, 12.2_

  - [ ] 10.2 Implement security filter
    - Create SecurityFilter class to detect and remove credentials, keys, secrets
    - Implement pattern matching for AWS keys, private keys, passwords, tokens
    - Add JSON/YAML scanning for sensitive fields
    - Test filter with various data formats
    - _Requirements: 12.5, 12.10_

  - [ ] 10.3 Implement workspace permission system
    - Create workspace permission checker
    - Implement allowed_workspaces configuration enforcement
    - Add authentication requirement for AI enablement
    - Prevent remote or malicious enablement
    - _Requirements: 12.4, 12.10_

  - [ ] 10.4 Implement audit logging
    - Create audit log system for all AI queries and responses
    - Log query content, data sent size, provider used, user approval status
    - Store logs in secure location with tamper detection
    - _Requirements: 12.6_

  - [ ] 10.5 Implement local LLM support (Ollama)
    - Create Ollama provider plugin
    - Implement local-only mode configuration
    - Add Ollama installation to build system
    - Test offline AI operation
    - _Requirements: 12.3_

  - [ ] 10.6 Implement cloud AI provider plugins
    - Create OpenAI provider plugin
    - Create Anthropic provider plugin
    - Create Amazon Q provider plugin (optional)
    - Implement provider plugin registration system
    - _Requirements: 12.2_

  - [ ] 10.7 Implement read-only mode and approval workflow
    - Set AI to read-only mode by default
    - Create approval workflow for AI-suggested modifications
    - Implement user confirmation prompts
    - Add approval logging
    - _Requirements: 12.7, 12.8_

  - [ ] 10.8 Create AI CLI tool
    - Implement nubifer-ai command-line tool
    - Add commands: enable, disable, query, status, providers, configure, history, test
    - Integrate with Context Manager for workspace awareness
    - _Requirements: 12.1, 12.2, 12.4_

  - [ ] 10.9 Implement privacy controls
    - Add data anonymization options (account IDs, resource names)
    - Implement local-only mode enforcement
    - Add data minimization (send only necessary context)
    - Create transparency logging (show what data is sent)
    - _Requirements: 12.9_

  - [ ] 10.10 Create systemd service definition
    - Write systemd service file for AI Assistant
    - Configure service dependencies (requires Context Manager, Credential Manager)
    - Set up service to start on demand (not by default)
    - _Requirements: 12.1_

  - [ ] 10.11 Integrate AI into Resource Viewer
    - Add AI chat panel to Resource Viewer UI
    - Implement natural language search bar
    - Add AI suggestions for cost optimization
    - Show AI status indicator
    - _Requirements: 12.2_

- [x] 11. System integration and configuration
  - [x] 11.1 Create system configuration files
    - Create /etc/nubiferos/ directory structure
    - Add default configurations for cloud tools
    - Create shell integration script
    - _Requirements: 1.4_
    - _Note: Created configs/nubiferos/ with provider configs_

  - [x] 11.2 Configure service dependencies
    - Ensure Context Manager starts after Credential Manager
    - Configure desktop environment to load context indicator on login
    - _Requirements: 1.5_
    - _Note: Systemd services deferred to beta - shell integration via /etc/bash.bashrc_

  - [x] 11.3 Add NubiferOS branding
    - Create custom wallpapers for each cloud provider
    - Design NubiferOS logo and icons emphasizing security
    - Configure GRUB bootloader with NubiferOS theme
    - _Requirements: 1.2_
    - _Note: Wallpapers in brand/wallpapers/, installed via install-branding-assets.sh_

  - [ ] 11.4 Create security documentation
    - Write security best practices guide
    - Document encryption and credential protection features
    - Create incident response guide
    - Document security update process
    - _Requirements: 11.8, 12.2_

  - [ ] 11.5 Create user documentation
    - Write user guide for workspace management
    - Document credential setup process
    - Create quick start guide
    - _Requirements: 12.2_

- [ ]* 12. Testing and validation
  - [ ]* 12.1 Test build system
    - Verify ISO builds successfully in clean environment
    - Verify GPG signature on downloaded Debian ISO
    - Verify all cloud tools are installed and functional
    - Verify all security hardening is applied
    - _Requirements: 12.5_

  - [ ]* 12.2 Test installation
    - Install NubiferOS in VirtualBox VM with LUKS encryption
    - Verify encryption passphrase is required at boot
    - Verify all services start correctly
    - Test desktop environment loads properly
    - Verify firewall is enabled and blocking incoming connections
    - Verify AppArmor profiles are loaded
    - _Requirements: 11.1, 11.5, 11.6, 11.7, 12.4, 12.6_

  - [ ]* 12.3 Test credential management
    - Test adding AWS, Azure, and GCP credentials
    - Verify credentials are encrypted in keyring with additional encryption layer
    - Verify credentials are never written to disk in plain text
    - Test credential retrieval and injection
    - Test credential memory protection (mlock)
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 11.2_

  - [ ]* 12.4 Test workspace management
    - Create multiple workspaces for different accounts
    - Test switching between workspaces
    - Verify environment isolation
    - Verify context indicator updates correctly
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 5.1, 5.5_

  - [ ]* 12.5 Test read-only mode
    - Enable read-only mode on a workspace
    - Verify write operations are blocked
    - Test with aws, az, and gcloud CLI commands
    - _Requirements: 8.1, 8.2, 8.3, 8.4_

  - [ ]* 12.6 Test resource viewer
    - Add credentials for an AWS account
    - Sync resources and verify they appear in database
    - Test browsing resources in UI
    - Test offline mode with cached data
    - _Requirements: 6.1, 6.2, 6.3, 7.1, 7.2, 7.3, 7.4_

  - [ ]* 12.7 Test AI Assistant
    - Test AI enablement and authentication
    - Test security filter with various sensitive data patterns
    - Test workspace permission enforcement
    - Test local LLM (Ollama) operation
    - Test cloud provider integration (OpenAI)
    - Test audit logging
    - Test read-only mode and approval workflow
    - Verify credentials are never sent to AI
    - _Requirements: 12.1, 12.2, 12.3, 12.4, 12.5, 12.6, 12.7, 12.8, 12.9, 12.10_

  - [ ]* 12.8 Integration testing
    - Test complete workflow: install → add credentials → create workspace → sync resources → browse
    - Test multi-workspace scenario with different cloud providers
    - Test workspace switching with context indicator updates
    - _Requirements: All_
