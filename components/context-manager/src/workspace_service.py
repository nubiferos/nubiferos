#!/usr/bin/env python3
"""
NubiferOS Context Manager - Workspace Service
Core workspace management with SQLite backend
"""

import sqlite3
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
    Uses SQLite for workspace metadata and configuration.
    """
    
    SUPPORTED_PROVIDERS = ['aws', 'azure', 'gcp', 'oracle', 'multi']
    
    PROVIDER_COLORS = {
        'aws': {'name': 'AWS', 'color': '#FF9900', 'terminal_color': '208', 'icon': '☁️'},
        'azure': {'name': 'Azure', 'color': '#0078D4', 'terminal_color': '33', 'icon': '⛅'},
        'gcp': {'name': 'GCP', 'color': '#4285F4', 'terminal_color': '33', 'icon': '🔵'},
        'oracle': {'name': 'Oracle', 'color': '#FF0000', 'terminal_color': '196', 'icon': '🔴'},
        'multi': {'name': 'Multi-Cloud', 'color': '#6B46C1', 'terminal_color': '99', 'icon': '🌐'}
    }
    
    def __init__(self, db_path: Optional[Path] = None):
        """Initialize workspace service"""
        if db_path is None:
            config_dir = Path.home() / ".config" / "nubiferos"
            config_dir.mkdir(parents=True, exist_ok=True, mode=0o700)
            db_path = config_dir / "workspaces.db"
        
        self.db_path = db_path
        self.current_workspace_file = db_path.parent / "current-workspace"
        self._init_database()
    
    def _init_database(self):
        """Initialize SQLite database for workspaces"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS workspaces (
                workspace_id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                provider TEXT NOT NULL,
                account_id TEXT NOT NULL,
                account_name TEXT,
                region TEXT,
                credential_id TEXT,
                read_only INTEGER DEFAULT 0,
                created_at TEXT NOT NULL,
                last_used TEXT,
                theme_json TEXT,
                environment_json TEXT
            )
        """)
        
        conn.commit()
        conn.close()
        
        logger.info(f"Initialized workspace database: {self.db_path}")
    
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
            'NUBIFEROS_PROVIDER': provider,
            'NUBIFEROS_ACCOUNT': account_name or account_id,
            'NUBIFEROS_ACCOUNT_ID': account_id,
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
                'GCP_PROJECT': account_id,
                'GCP_REGION': region,
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
        
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        now = datetime.utcnow().isoformat()
        
        try:
            cursor.execute("""
                INSERT INTO workspaces 
                (workspace_id, name, provider, account_id, account_name, region, 
                 credential_id, read_only, created_at, theme_json, environment_json)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                workspace_id, name, provider, account_id, account_name, region,
                credential_id, 1 if read_only else 0, now,
                json.dumps(theme), json.dumps(environment)
            ))
            
            conn.commit()
            logger.info(f"Created workspace: {workspace_id} ({name})")
            return workspace_id
            
        except sqlite3.Error as e:
            logger.error(f"Database error: {e}")
            raise WorkspaceServiceError(f"Failed to create workspace: {e}")
        finally:
            conn.close()
    
    def get_workspace(self, workspace_id: str) -> Optional[Dict]:
        """Get workspace by ID"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT workspace_id, name, provider, account_id, account_name, region,
                   credential_id, read_only, created_at, last_used, theme_json, environment_json
            FROM workspaces
            WHERE workspace_id = ?
        """, (workspace_id,))
        
        row = cursor.fetchone()
        conn.close()
        
        if not row:
            return None
        
        return {
            'workspace_id': row[0],
            'name': row[1],
            'provider': row[2],
            'account_id': row[3],
            'account_name': row[4],
            'region': row[5],
            'credential_id': row[6],
            'read_only': bool(row[7]),
            'created_at': row[8],
            'last_used': row[9],
            'theme': json.loads(row[10]) if row[10] else {},
            'environment': json.loads(row[11]) if row[11] else {}
        }
    
    def list_workspaces(self, provider: Optional[str] = None) -> List[Dict]:
        """List all workspaces"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        if provider:
            cursor.execute("""
                SELECT workspace_id, name, provider, account_id, account_name, region,
                       credential_id, read_only, created_at, last_used, theme_json, environment_json
                FROM workspaces
                WHERE provider = ?
                ORDER BY last_used DESC, name ASC
            """, (provider,))
        else:
            cursor.execute("""
                SELECT workspace_id, name, provider, account_id, account_name, region,
                       credential_id, read_only, created_at, last_used, theme_json, environment_json
                FROM workspaces
                ORDER BY last_used DESC, name ASC
            """)
        
        workspaces = []
        for row in cursor.fetchall():
            workspaces.append({
                'workspace_id': row[0],
                'name': row[1],
                'provider': row[2],
                'account_id': row[3],
                'account_name': row[4],
                'region': row[5],
                'credential_id': row[6],
                'read_only': bool(row[7]),
                'created_at': row[8],
                'last_used': row[9],
                'theme': json.loads(row[10]) if row[10] else {},
                'environment': json.loads(row[11]) if row[11] else {}
            })
        
        conn.close()
        return workspaces
    
    def delete_workspace(self, workspace_id: str) -> bool:
        """Delete a workspace"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("DELETE FROM workspaces WHERE workspace_id = ?", (workspace_id,))
        deleted = cursor.rowcount > 0
        
        conn.commit()
        conn.close()
        
        if deleted:
            logger.info(f"Deleted workspace: {workspace_id}")
        
        return deleted
    
    def set_read_only(self, workspace_id: str, read_only: bool) -> bool:
        """Set read-only mode for workspace"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
            UPDATE workspaces
            SET read_only = ?
            WHERE workspace_id = ?
        """, (1 if read_only else 0, workspace_id))
        
        updated = cursor.rowcount > 0
        conn.commit()
        conn.close()
        
        if updated:
            logger.info(f"Set read_only={read_only} for workspace: {workspace_id}")
        
        return updated
    
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
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        now = datetime.utcnow().isoformat()
        cursor.execute("""
            UPDATE workspaces
            SET last_used = ?
            WHERE workspace_id = ?
        """, (now, workspace_id))
        
        conn.commit()
        conn.close()
        
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
