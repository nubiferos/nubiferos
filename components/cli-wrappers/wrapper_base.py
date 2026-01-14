#!/usr/bin/env python3
"""
NubiferOS CLI Wrapper Base
Common functionality for all CLI wrappers
"""

import os
import sys
import subprocess
import dbus
import logging

logger = logging.getLogger(__name__)


class WrapperError(Exception):
    """Base exception for wrapper errors"""
    pass


class NoWorkspaceError(WrapperError):
    """Raised when no workspace is active"""
    pass


class ReadOnlyError(WrapperError):
    """Raised when operation is blocked in read-only mode"""
    pass


class CLIWrapperBase:
    """
    Base class for CLI wrappers.
    Handles workspace detection, credential injection, and read-only enforcement.
    """
    
    def __init__(self, cli_name: str, real_binary_path: str):
        """
        Initialize wrapper.
        
        Args:
            cli_name: Name of CLI tool (e.g., 'aws', 'az')
            real_binary_path: Path to real binary (e.g., '/usr/bin/aws')
        """
        self.cli_name = cli_name
        self.real_binary_path = real_binary_path
        
        # Check if real binary exists
        if not os.path.exists(real_binary_path):
            raise WrapperError(f"Real binary not found: {real_binary_path}")
    
    def get_current_workspace(self):
        """Get current workspace from Context Manager via D-Bus"""
        try:
            bus = dbus.SessionBus()
            service = bus.get_object(
                'org.nubiferos.ContextManager',
                '/org/nubiferos/ContextManager'
            )
            
            workspace = service.GetCurrentWorkspace(
                dbus_interface='org.nubiferos.ContextManager'
            )
            
            if not workspace:
                return None
            
            # Convert dbus.Dictionary to regular dict
            return dict(workspace)
            
        except dbus.DBusException as e:
            logger.error(f"D-Bus error: {e}")
            return None
    
    def get_credentials(self, provider: str, account_id: str):
        """Get credentials from Credential Manager via D-Bus"""
        try:
            bus = dbus.SessionBus()
            service = bus.get_object(
                'org.nubiferos.CredentialManager',
                '/org/nubiferos/CredentialManager'
            )
            
            credentials = service.GetCredential(
                provider,
                account_id,
                dbus_interface='org.nubiferos.CredentialManager'
            )
            
            if not credentials:
                return None
            
            # Convert dbus.Dictionary to regular dict
            return dict(credentials)
            
        except dbus.DBusException as e:
            logger.error(f"D-Bus error: {e}")
            return None
    
    def is_write_operation(self, args: list) -> bool:
        """
        Check if command is a write operation.
        Must be implemented by subclasses.
        """
        raise NotImplementedError("Subclass must implement is_write_operation()")
    
    def inject_credentials(self, credentials: dict, env: dict) -> dict:
        """
        Inject credentials into environment.
        Must be implemented by subclasses.
        
        Args:
            credentials: Credentials from credential manager
            env: Current environment dict
        
        Returns:
            Updated environment dict
        """
        raise NotImplementedError("Subclass must implement inject_credentials()")
    
    def check_workspace_active(self):
        """Check if a workspace is active"""
        workspace_id = os.environ.get('NUBIFEROS_WORKSPACE_ID')
        
        if not workspace_id:
            raise NoWorkspaceError(
                "No active workspace. Activate one with:\n"
                "  nubifer-workspace list\n"
                "  eval $(nubifer-workspace env <workspace-id>)"
            )
    
    def enforce_read_only(self, workspace: dict, args: list):
        """Enforce read-only mode if enabled"""
        if not workspace.get('read_only'):
            return  # Not in read-only mode
        
        if self.is_write_operation(args):
            workspace_name = workspace.get('name', 'Unknown')
            workspace_id = workspace.get('workspace_id', '')
            
            raise ReadOnlyError(
                f"❌ Operation blocked: Workspace '{workspace_name}' is in READ-ONLY mode.\n"
                f"   Use 'nubifer-workspace set-readonly {workspace_id} false' to enable writes."
            )
    
    def execute(self, args: list):
        """
        Execute the wrapped CLI tool with credential injection and security checks.
        
        Args:
            args: Command-line arguments (excluding program name)
        """
        try:
            # Check if workspace is active
            self.check_workspace_active()
            
            # Get current workspace
            workspace = self.get_current_workspace()
            if not workspace:
                raise NoWorkspaceError("Failed to get current workspace")
            
            # Enforce read-only mode
            self.enforce_read_only(workspace, args)
            
            # Get credentials if credential_id is set
            credentials = None
            if workspace.get('credential_id'):
                credentials = self.get_credentials(
                    workspace['provider'],
                    workspace['account_id']
                )
            
            # Prepare environment
            env = os.environ.copy()
            
            # Inject credentials if available
            if credentials:
                env = self.inject_credentials(credentials, env)
            
            # Execute real CLI tool
            cmd = [self.real_binary_path] + args
            result = subprocess.run(cmd, env=env)
            
            sys.exit(result.returncode)
            
        except NoWorkspaceError as e:
            print(f"\n{Colors.YELLOW}⚠ {e}{Colors.END}\n", file=sys.stderr)
            sys.exit(1)
        
        except ReadOnlyError as e:
            print(f"\n{e}\n", file=sys.stderr)
            sys.exit(1)
        
        except WrapperError as e:
            print(f"\n{Colors.RED}✗ Error: {e}{Colors.END}\n", file=sys.stderr)
            sys.exit(1)
        
        except Exception as e:
            print(f"\n{Colors.RED}✗ Unexpected error: {e}{Colors.END}\n", file=sys.stderr)
            sys.exit(1)


class Colors:
    """ANSI color codes"""
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    BLUE = '\033[94m'
    BOLD = '\033[1m'
    END = '\033[0m'
