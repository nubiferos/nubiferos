#!/usr/bin/env python3
"""
NubiferOS Credential Manager Service
Manages cloud credentials using pass (password-store) with SQLite metadata.
"""

import sqlite3
import logging
import json
from pathlib import Path
from typing import Optional, Dict, List, Tuple
from datetime import datetime

from pass_backend import PassBackend, PassBackendError, PassNotInitializedError

logger = logging.getLogger(__name__)


class CredentialServiceError(Exception):
    """Base exception for credential service errors"""
    pass


class CredentialService:
    """
    Credential management service.
    Uses pass for encrypted storage and SQLite for metadata.
    """
    
    SUPPORTED_PROVIDERS = ['aws', 'azure', 'gcp']
    
    def __init__(self, db_path: Optional[Path] = None):
        """Initialize credential service"""
        if db_path is None:
            config_dir = Path.home() / ".config" / "nubiferos"
            config_dir.mkdir(parents=True, exist_ok=True)
            db_path = config_dir / "credentials.db"
        
        self.db_path = db_path
        self.pass_backend = PassBackend()
        self._init_database()
    
    def _init_database(self):
        """Initialize SQLite database for credential metadata"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS credentials (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                provider TEXT NOT NULL,
                account_id TEXT NOT NULL,
                account_name TEXT NOT NULL,
                auth_type TEXT NOT NULL,
                pass_path_prefix TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                UNIQUE(provider, account_id)
            )
        """)
        
        conn.commit()
        conn.close()
        
        logger.info(f"Initialized credential database: {self.db_path}")
    
    def check_prerequisites(self) -> Tuple[bool, List[str]]:
        """
        Check if all prerequisites are met.
        Returns (success, list of issues)
        """
        issues = []
        
        # Check if pass is initialized
        if not self.pass_backend.is_initialized():
            gpg_keys = self.pass_backend.list_gpg_keys()
            if not gpg_keys:
                issues.append("No GPG keys found. Create one with: gpg --gen-key")
            else:
                issues.append(
                    f"Pass store not initialized. Run: pass init <gpg-key-id>\n"
                    f"Available GPG keys:\n" +
                    "\n".join([f"  - {k['keyid']}: {k['uid']}" for k in gpg_keys])
                )
        
        return (len(issues) == 0, issues)
    
    def add_credential(
        self,
        provider: str,
        account_id: str,
        account_name: str,
        credentials: Dict[str, str]
    ) -> bool:
        """
        Add or update credentials for an account.
        
        Args:
            provider: Cloud provider (aws, azure, gcp)
            account_id: Account identifier
            account_name: Human-readable account name
            credentials: Dict of credential key-value pairs
        
        Returns:
            True if successful
        """
        # Validate provider
        if provider not in self.SUPPORTED_PROVIDERS:
            raise CredentialServiceError(
                f"Unsupported provider: {provider}. "
                f"Supported: {', '.join(self.SUPPORTED_PROVIDERS)}"
            )
        
        # Validate credentials based on provider
        self._validate_credentials(provider, credentials)
        
        # Store credentials in pass
        try:
            for key, value in credentials.items():
                self.pass_backend.store_credential(provider, account_id, key, value)
        except PassBackendError as e:
            raise CredentialServiceError(f"Failed to store credentials: {e}")
        
        # Store metadata in SQLite
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        now = datetime.utcnow().isoformat()
        pass_path_prefix = f"{PassBackend.PASS_STORE_PREFIX}/{provider}/{account_id}"
        auth_type = self._get_auth_type(provider, credentials)
        
        try:
            cursor.execute("""
                INSERT INTO credentials 
                (provider, account_id, account_name, auth_type, pass_path_prefix, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(provider, account_id) DO UPDATE SET
                    account_name = excluded.account_name,
                    auth_type = excluded.auth_type,
                    updated_at = excluded.updated_at
            """, (provider, account_id, account_name, auth_type, pass_path_prefix, now, now))
            
            conn.commit()
            logger.info(f"Added credential: {provider}/{account_id}")
            return True
            
        except sqlite3.Error as e:
            logger.error(f"Database error: {e}")
            raise CredentialServiceError(f"Failed to store metadata: {e}")
        finally:
            conn.close()
    
    def get_credential(self, provider: str, account_id: str) -> Optional[Dict[str, str]]:
        """
        Retrieve credentials for an account.
        
        Returns:
            Dict with credential keys, or None if not found
        """
        # Get metadata from SQLite
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT auth_type FROM credentials
            WHERE provider = ? AND account_id = ?
        """, (provider, account_id))
        
        row = cursor.fetchone()
        conn.close()
        
        if not row:
            return None
        
        auth_type = row[0]
        
        # Retrieve credentials from pass based on auth type
        try:
            if provider == 'aws':
                return {
                    'access_key_id': self.pass_backend.retrieve_credential(
                        provider, account_id, 'access_key_id'
                    ),
                    'secret_access_key': self.pass_backend.retrieve_credential(
                        provider, account_id, 'secret_access_key'
                    )
                }
            elif provider == 'azure':
                return {
                    'client_id': self.pass_backend.retrieve_credential(
                        provider, account_id, 'client_id'
                    ),
                    'client_secret': self.pass_backend.retrieve_credential(
                        provider, account_id, 'client_secret'
                    ),
                    'tenant_id': self.pass_backend.retrieve_credential(
                        provider, account_id, 'tenant_id'
                    )
                }
            elif provider == 'gcp':
                # GCP stores JSON key file
                key_json = self.pass_backend.retrieve_credential(
                    provider, account_id, 'service_account_key'
                )
                return {'service_account_key': key_json}
            
        except PassBackendError as e:
            logger.error(f"Failed to retrieve credentials: {e}")
            return None
    
    def list_accounts(self, provider: Optional[str] = None) -> List[Dict[str, str]]:
        """
        List all accounts, optionally filtered by provider.
        
        Returns:
            List of dicts with account metadata
        """
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        if provider:
            cursor.execute("""
                SELECT provider, account_id, account_name, auth_type, created_at, updated_at
                FROM credentials
                WHERE provider = ?
                ORDER BY provider, account_name
            """, (provider,))
        else:
            cursor.execute("""
                SELECT provider, account_id, account_name, auth_type, created_at, updated_at
                FROM credentials
                ORDER BY provider, account_name
            """)
        
        accounts = []
        for row in cursor.fetchall():
            accounts.append({
                'provider': row[0],
                'account_id': row[1],
                'account_name': row[2],
                'auth_type': row[3],
                'created_at': row[4],
                'updated_at': row[5]
            })
        
        conn.close()
        return accounts
    
    def delete_credential(self, provider: str, account_id: str) -> bool:
        """Delete credentials for an account"""
        # Delete from pass
        try:
            self.pass_backend.delete_account(provider, account_id)
        except PassBackendError as e:
            logger.warning(f"Failed to delete from pass: {e}")
        
        # Delete from SQLite
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute("""
            DELETE FROM credentials
            WHERE provider = ? AND account_id = ?
        """, (provider, account_id))
        
        deleted = cursor.rowcount > 0
        conn.commit()
        conn.close()
        
        if deleted:
            logger.info(f"Deleted credential: {provider}/{account_id}")
        
        return deleted
    
    def test_credential(self, provider: str, account_id: str) -> Tuple[bool, str]:
        """
        Test if credentials work by attempting to retrieve them.
        
        Returns:
            (success, message)
        """
        creds = self.get_credential(provider, account_id)
        
        if not creds:
            return (False, "Credentials not found")
        
        # Check if all required fields are present and non-empty
        if provider == 'aws':
            if not creds.get('access_key_id') or not creds.get('secret_access_key'):
                return (False, "Missing AWS credentials")
        elif provider == 'azure':
            if not all([creds.get('client_id'), creds.get('client_secret'), creds.get('tenant_id')]):
                return (False, "Missing Azure credentials")
        elif provider == 'gcp':
            if not creds.get('service_account_key'):
                return (False, "Missing GCP service account key")
            # Validate JSON
            try:
                json.loads(creds['service_account_key'])
            except json.JSONDecodeError:
                return (False, "Invalid GCP service account key JSON")
        
        return (True, "Credentials retrieved successfully")
    
    def _validate_credentials(self, provider: str, credentials: Dict[str, str]):
        """Validate credentials based on provider requirements"""
        if provider == 'aws':
            required = ['access_key_id', 'secret_access_key']
            missing = [k for k in required if k not in credentials]
            if missing:
                raise CredentialServiceError(f"Missing AWS credentials: {', '.join(missing)}")
        
        elif provider == 'azure':
            required = ['client_id', 'client_secret', 'tenant_id']
            missing = [k for k in required if k not in credentials]
            if missing:
                raise CredentialServiceError(f"Missing Azure credentials: {', '.join(missing)}")
        
        elif provider == 'gcp':
            if 'service_account_key' not in credentials:
                raise CredentialServiceError("Missing GCP service_account_key")
            # Validate JSON
            try:
                json.loads(credentials['service_account_key'])
            except json.JSONDecodeError:
                raise CredentialServiceError("Invalid GCP service account key JSON")
    
    def _get_auth_type(self, provider: str, credentials: Dict[str, str]) -> str:
        """Determine authentication type from credentials"""
        if provider == 'aws':
            return 'access_key'
        elif provider == 'azure':
            return 'service_principal'
        elif provider == 'gcp':
            return 'service_account'
        return 'unknown'
