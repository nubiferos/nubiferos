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
            # Use same directory as nubifer-workspace CLI
            config_dir = Path.home() / ".config" / "nubifer"
        
        self.config_dir = config_dir
        self.workspace_dir = config_dir / "workspaces"
        self.current_workspace_file = config_dir / "current-workspace"
        
        # Ensure directories exist
        self.config_dir.mkdir(parents=True, exist_ok=True, mode=0o700)
        self.workspace_dir.mkdir(parents=True, exist_ok=True, mode=0o700)
        
        logger.info(f"Initialized workspace service: {self.workspace_dir}")
    
    def _generate_workspace_id(self, name: str) -> str:
        """Generate unique workspace ID"""
        unique_str = f"{name}-{time.time()}"
        hash_obj = hashlib.sha256(unique_str.encode())
        return hash_obj.hexdigest()[:16]
    
    def _get_default_region(self, provider: str) -> str:
        """Get default region for provider"""
        defaults = {
            'aws': 'us-east-1',
            'azure': 'eastus',
            'gcp': 'us-central1',
            'oracle': 'us-ashburn-1',
            'multi': None
        }
        return defaults.get(provider, '')
    
    def _build_environment(self, provider: str, account_id: str, 
                          account_name: str, region: str) -> Dict[str, str]:
        """Build environment variables for workspace"""
        env = {
            'NUBIFER_WORKSPACE_PROVIDER': provider,
            'NUBIFER_WORKSPACE_ACCOUNT': account_name or account_id,
            'NUBIFER_WORKSPACE_ACCOUNT_ID': account_id,
        }
        
        if provider == 'aws':
            env.update({
                'AWS_DEFAULT_REGION': region,
                'AWS_REGION': region,
                'AWS_ACCOUNT_ID': account_id,
            })
        elif provider == 'azure':
            env.update({
                'AZURE_LOCATION': region,
                'AZURE_SUBSCRIPTION_ID': account_id,
            })
        elif provider == 'gcp':
            env.update({
                'GOOGLE_CLOUD_PROJECT': account_id,
                'GOOGLE_CLOUD_REGION': region,
            })
        elif provider == 'oracle':
            env.update({
                'OCI_REGION': region,
                'OCI_TENANCY': account_id,
            })
        
        return env
    
    def create_workspace(
        self,
        name: str,
        provider: str,
        account_id: str,
        account_name: Optional[str] = None,
        region: Optional[str] = None,
        credential_id: Optional[str] = None,
        read_only: bool = False
    ) -> str:
        """Create a new workspace"""
        
        if provider not in self.SUPPORTED_PROVIDERS:
            raise WorkspaceServiceError(
                f"Unsupported provider: {provider}. "
                f"Supported: {', '.join(self.SUPPORTED_PROVIDERS)}"
            )
        
        workspace_id = self._generate_workspace_id(name)
        
        if not region:
            region = self._get_default_region(provider)
        
        if not account_name:
            account_name = account_id
        
        theme = self.PROVIDER_COLORS[provider]
        environment = self._build_environment(provider, account_id, account_name, region)
        
        now = datetime.utcnow().isoformat()
        
        workspace = {
            'workspace_id': workspace_id,
            'name': name,
            'provider': provider,
            'account_id': account_id,
            'account_name': account_name,
            'region': region,
            'credential_id': credential_id,
            'read_only': read_only,
            'created_at': now,
            'last_used': None,
            'theme': theme,
            'environment': environment
        }
        
        # Save as JSON file
        workspace_file = self.workspace_dir / f"{workspace_id}.json"
        with open(workspace_file, 'w') as f:
            json.dump(workspace, f, indent=2)
        workspace_file.chmod(0o600)
        
        logger.info(f"Created workspace: {workspace_id} ({name})")
        return workspace_id
    
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
                    
                    # Filter by provider if specified
                    if provider and workspace.get('provider') != provider:
                        continue
                    
                    workspaces.append(workspace)
            except Exception as e:
                logger.error(f"Failed to read workspace file {workspace_file}: {e}")
                continue
        
        # Sort by last used (most recent first), then by name
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
            logger.info(f"Set read_only={read_only} for workspace: {workspace_id}")
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
        """Set current workspace and update last_used"""
        workspace = self.get_workspace(workspace_id)
        
        if not workspace:
            return False
        
        # Update last_used timestamp
        workspace['last_used'] = datetime.utcnow().isoformat()
        
        workspace_file = self.workspace_dir / f"{workspace_id}.json"
        try:
            with open(workspace_file, 'w') as f:
                json.dump(workspace, f, indent=2)
        except Exception as e:
            logger.error(f"Failed to update workspace {workspace_id}: {e}")
        
        # Write current workspace file
        try:
            with open(self.current_workspace_file, 'w') as f:
                f.write(workspace_id)
            self.current_workspace_file.chmod(0o600)
            
            logger.info(f"Set current workspace: {workspace_id}")
            return True
        except Exception as e:
            logger.error(f"Failed to set current workspace: {e}")
            return False
