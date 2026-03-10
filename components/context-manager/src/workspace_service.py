#!/usr/bin/env python3
"""
NubiferOS Context Manager - Workspace Service
Core workspace management - reads from JSON files created by nubifer-workspace CLI
"""

import json
import logging
from pathlib import Path
from typing import Optional, Dict, List
from datetime import datetime
import hashlib
import time

logger = logging.getLogger(__name__)


class WorkspaceServiceError(Exception):
    """Base exception for workspace service errors"""
    pass


class WorkspaceService:
    """
    Workspace management service.
    Reads workspace JSON files from ~/.config/nubifer/workspaces/
    This ensures compatibility with the nubifer-workspace CLI tool.
    """
    
    SUPPORTED_PROVIDERS = ['aws', 'azure', 'gcp', 'oracle', 'multi']
    
    PROVIDER_COLORS = {
        'aws': {'name': 'AWS', 'color': '#FF9900', 'terminal_color': '208', 'icon': '☁️'},
        'azure': {'name': 'Azure', 'color': '#0078D4', 'terminal_color': '33', 'icon': '⛅'},
        'gcp': {'name': 'GCP', 'color': '#4285F4', 'terminal_color': '33', 'icon': '🔵'},
        'oracle': {'name': 'Oracle', 'color': '#FF0000', 'terminal_color': '196', 'icon': '🔴'},
        'multi': {'name': 'Multi-Cloud', 'color': '#6B46C1', 'terminal_color': '99', 'icon': '🌐'}
    }
    
    def __init__(self, config_dir: Optional[Path] = None):
        """Initialize workspace service"""
        if config_dir is None:
            config_dir = Path.home() / ".config" / "nubifer"
        
        self.config_dir = config_dir
        self.workspace_dir = config_dir / "workspaces"
        self.current_workspace_file = config_dir / "current-workspace"
        
        self.config_dir.mkdir(parents=True, exist_ok=True, mode=0o700)
        self.workspace_dir.mkdir(parents=True, exist_ok=True, mode=0o700)
        logger.info(f"Initialized workspace service: {self.workspace_dir}")

    def create_workspace(self, name: str, provider: str, account_id: str,
                         account_name: Optional[str] = None, region: Optional[str] = None,
                         credential_id: Optional[str] = None, read_only: bool = False) -> str:
        """Create a new workspace and return its ID"""
        if provider not in self.SUPPORTED_PROVIDERS:
            raise WorkspaceServiceError(f"Unsupported provider: {provider}")

        # Generate workspace ID from name + account
        workspace_id = hashlib.sha256(
            f"{name}-{provider}-{account_id}-{time.time()}".encode()
        ).hexdigest()[:12]

        # Get provider theme
        theme = self.PROVIDER_COLORS.get(provider, self.PROVIDER_COLORS['multi']).copy()

        # Build provider-specific environment variables
        environment = {}
        if provider == 'aws':
            if region:
                environment['AWS_REGION'] = region
                environment['AWS_DEFAULT_REGION'] = region
        elif provider == 'azure':
            if region:
                environment['AZURE_LOCATION'] = region
        elif provider == 'gcp':
            if region:
                environment['CLOUDSDK_COMPUTE_REGION'] = region
            environment['CLOUDSDK_CORE_PROJECT'] = account_id
        elif provider == 'oracle':
            if region:
                environment['OCI_CLI_REGION'] = region

        workspace = {
            'workspace_id': workspace_id,
            'name': name,
            'provider': provider,
            'account_id': account_id,
            'account_name': account_name or account_id,
            'region': region or '',
            'credential_id': credential_id or '',
            'read_only': read_only,
            'theme': theme,
            'environment': environment,
            'created_at': datetime.utcnow().isoformat(),
            'last_used': '',
        }

        workspace_file = self.workspace_dir / f"{workspace_id}.json"
        try:
            with open(workspace_file, 'w') as f:
                json.dump(workspace, f, indent=2)
            workspace_file.chmod(0o600)
            logger.info(f"Created workspace: {workspace_id} ({name})")
            return workspace_id
        except Exception as e:
            raise WorkspaceServiceError(f"Failed to create workspace: {e}")

    def get_workspace(self, workspace_id: str) -> Optional[Dict]:
        """Get workspace by ID"""
        workspace_file = self.workspace_dir / f"{workspace_id}.json"
        if not workspace_file.exists():
            return None
        try:
            with open(workspace_file, 'r') as f:
                return json.load(f)
        except Exception as e:
            logger.error(f"Failed to read workspace {workspace_id}: {e}")
            return None
    
    def list_workspaces(self, provider: Optional[str] = None) -> List[Dict]:
        """List all workspaces"""
        workspaces = []
        for workspace_file in self.workspace_dir.glob('*.json'):
            try:
                with open(workspace_file, 'r') as f:
                    workspace = json.load(f)
                    if provider and workspace.get('provider') != provider:
                        continue
                    workspaces.append(workspace)
            except Exception as e:
                logger.error(f"Failed to read workspace file {workspace_file}: {e}")
        workspaces.sort(key=lambda w: (w.get('last_used') or '', w.get('name', '')), reverse=True)
        return workspaces
    
    def delete_workspace(self, workspace_id: str) -> bool:
        """Delete a workspace"""
        workspace_file = self.workspace_dir / f"{workspace_id}.json"
        if not workspace_file.exists():
            return False
        try:
            workspace_file.unlink()
            logger.info(f"Deleted workspace: {workspace_id}")
            return True
        except Exception as e:
            logger.error(f"Failed to delete workspace {workspace_id}: {e}")
            return False
    
    def set_read_only(self, workspace_id: str, read_only: bool) -> bool:
        """Set read-only mode for workspace"""
        workspace = self.get_workspace(workspace_id)
        if not workspace:
            return False
        workspace['read_only'] = read_only
        workspace_file = self.workspace_dir / f"{workspace_id}.json"
        try:
            with open(workspace_file, 'w') as f:
                json.dump(workspace, f, indent=2)
            return True
        except Exception as e:
            logger.error(f"Failed to update workspace {workspace_id}: {e}")
            return False
    
    def get_current_workspace(self) -> Optional[Dict]:
        """Get currently active workspace"""
        if not self.current_workspace_file.exists():
            return None
        try:
            with open(self.current_workspace_file, 'r') as f:
                workspace_id = f.read().strip()
            return self.get_workspace(workspace_id)
        except Exception as e:
            logger.error(f"Failed to get current workspace: {e}")
            return None
    
    def set_current_workspace(self, workspace_id: str) -> bool:
        """Set current workspace"""
        workspace = self.get_workspace(workspace_id)
        if not workspace:
            return False
        workspace['last_used'] = datetime.utcnow().isoformat()
        workspace_file = self.workspace_dir / f"{workspace_id}.json"
        try:
            with open(workspace_file, 'w') as f:
                json.dump(workspace, f, indent=2)
            with open(self.current_workspace_file, 'w') as f:
                f.write(workspace_id)
            self.current_workspace_file.chmod(0o600)
            return True
        except Exception as e:
            logger.error(f"Failed to set current workspace: {e}")
            return False
