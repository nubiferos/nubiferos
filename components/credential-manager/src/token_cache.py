#!/usr/bin/env python3
"""
Token Cache for NubiferOS Credential Manager

Caches STS temporary tokens using OS keyring (with encrypted file fallback).
Metadata (expiration times) stored in SQLite.
"""

import json
import logging
import os
import sqlite3
import base64
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional, Dict, Any

logger = logging.getLogger(__name__)

# Refresh buffer - tokens within this many seconds of expiry are considered expired
TOKEN_REFRESH_BUFFER_SECONDS = 300  # 5 minutes


class TokenCacheError(Exception):
    """Base exception for token cache errors"""
    pass


class TokenCache:
    """
    Cache for STS temporary tokens.

    Primary storage: OS keyring (GNOME Keyring / libsecret)
    Fallback: Encrypted file in ~/.config/nubiferos/token_cache/
    Metadata: SQLite database for expiration tracking
    """

    def __init__(self, db_path: Optional[Path] = None):
        """Initialize token cache"""
        config_dir = Path.home() / ".config" / "nubiferos"
        config_dir.mkdir(parents=True, exist_ok=True)

        if db_path is None:
            db_path = config_dir / "token_cache.db"

        self.db_path = db_path
        self.cache_dir = config_dir / "token_cache"
        self.cache_dir.mkdir(parents=True, exist_ok=True, mode=0o700)

        self._keyring_available = self._check_keyring()
        self._init_database()

    def _check_keyring(self) -> bool:
        """Check if OS keyring is available"""
        try:
            import keyring
            # Try a test operation to verify keyring is functional
            keyring.get_keyring()
            return True
        except Exception as e:
            logger.warning(f"Keyring not available, using encrypted file fallback: {e}")
            return False

    def _init_database(self):
        """Initialize SQLite database for token metadata"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()

        cursor.execute("""
            CREATE TABLE IF NOT EXISTS token_metadata (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                workspace TEXT NOT NULL,
                provider TEXT NOT NULL,
                credential_name TEXT NOT NULL,
                token_type TEXT NOT NULL DEFAULT 'session',
                expires_at TEXT NOT NULL,
                created_at TEXT NOT NULL,
                storage_type TEXT NOT NULL DEFAULT 'keyring',
                token_enabled INTEGER NOT NULL DEFAULT 0,
                UNIQUE(workspace, provider, credential_name)
            )
        """)

        # Table for token mode settings
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS token_settings (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                workspace TEXT NOT NULL,
                provider TEXT NOT NULL,
                credential_name TEXT NOT NULL,
                enabled INTEGER NOT NULL DEFAULT 0,
                duration_seconds INTEGER NOT NULL DEFAULT 3600,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                UNIQUE(workspace, provider, credential_name)
            )
        """)

        conn.commit()
        conn.close()

        logger.debug(f"Initialized token cache database: {self.db_path}")

    def _get_cache_key(self, workspace: str, provider: str, credential_name: str) -> str:
        """Generate cache key for token storage"""
        return f"nubiferos-token:{workspace}:{provider}:{credential_name}"

    def _get_file_path(self, workspace: str, provider: str, credential_name: str) -> Path:
        """Get file path for encrypted file fallback"""
        # Sanitize names for filesystem
        safe_workspace = workspace.replace('/', '_').replace('..', '')
        safe_provider = provider.replace('/', '_').replace('..', '')
        safe_name = credential_name.replace('/', '_').replace('..', '')

        return self.cache_dir / f"{safe_workspace}_{safe_provider}_{safe_name}.enc"

    def _encrypt_token(self, token_data: Dict[str, Any]) -> bytes:
        """Encrypt token data for file storage"""
        try:
            from cryptography.fernet import Fernet
            from cryptography.hazmat.primitives import hashes
            from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC

            # Derive key from machine-specific data
            # This is not perfect security but provides obfuscation
            machine_id = self._get_machine_id()
            salt = b'nubiferos-token-cache-v1'

            kdf = PBKDF2HMAC(
                algorithm=hashes.SHA256(),
                length=32,
                salt=salt,
                iterations=100000,
            )
            key = base64.urlsafe_b64encode(kdf.derive(machine_id.encode()))

            f = Fernet(key)
            return f.encrypt(json.dumps(token_data).encode())

        except ImportError:
            # Fallback to base64 encoding if cryptography not available
            logger.warning("cryptography package not available, using base64 encoding")
            return base64.b64encode(json.dumps(token_data).encode())

    def _decrypt_token(self, encrypted_data: bytes) -> Dict[str, Any]:
        """Decrypt token data from file storage"""
        try:
            from cryptography.fernet import Fernet
            from cryptography.hazmat.primitives import hashes
            from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC

            machine_id = self._get_machine_id()
            salt = b'nubiferos-token-cache-v1'

            kdf = PBKDF2HMAC(
                algorithm=hashes.SHA256(),
                length=32,
                salt=salt,
                iterations=100000,
            )
            key = base64.urlsafe_b64encode(kdf.derive(machine_id.encode()))

            f = Fernet(key)
            decrypted = f.decrypt(encrypted_data)
            return json.loads(decrypted.decode())

        except ImportError:
            # Fallback from base64 encoding
            return json.loads(base64.b64decode(encrypted_data).decode())

    def _get_machine_id(self) -> str:
        """Get machine-specific ID for key derivation"""
        # Try various sources for machine ID
        try:
            if Path("/etc/machine-id").exists():
                return Path("/etc/machine-id").read_text().strip()
        except Exception:
            pass

        try:
            if Path("/var/lib/dbus/machine-id").exists():
                return Path("/var/lib/dbus/machine-id").read_text().strip()
        except Exception:
            pass

        # Fallback to hostname + user
        import socket
        return f"{socket.gethostname()}-{os.getenv('USER', 'unknown')}"

    def store_token(
        self,
        workspace: str,
        provider: str,
        credential_name: str,
        token_data: Dict[str, Any],
        expires_at: datetime
    ) -> bool:
        """
        Store a token in the cache.

        Args:
            workspace: Workspace ID
            provider: Cloud provider (aws, azure, gcp)
            credential_name: Credential profile name
            token_data: Token data dict (AccessKeyId, SecretAccessKey, SessionToken, etc.)
            expires_at: Token expiration time (UTC)

        Returns:
            True if successful
        """
        cache_key = self._get_cache_key(workspace, provider, credential_name)
        token_json = json.dumps(token_data)
        storage_type = 'keyring'

        # Try keyring first
        if self._keyring_available:
            try:
                import keyring
                keyring.set_password("nubiferos", cache_key, token_json)
                logger.debug(f"Stored token in keyring: {cache_key}")
            except Exception as e:
                logger.warning(f"Failed to store in keyring, using file fallback: {e}")
                self._keyring_available = False
                storage_type = 'file'

        # Fallback to encrypted file
        if not self._keyring_available:
            try:
                file_path = self._get_file_path(workspace, provider, credential_name)
                encrypted = self._encrypt_token(token_data)
                file_path.write_bytes(encrypted)
                file_path.chmod(0o600)
                storage_type = 'file'
                logger.debug(f"Stored token in encrypted file: {file_path}")
            except Exception as e:
                logger.error(f"Failed to store token: {e}")
                return False

        # Store metadata in SQLite
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()

        now = datetime.now(timezone.utc).isoformat()
        expires_at_str = expires_at.isoformat() if expires_at.tzinfo else expires_at.replace(tzinfo=timezone.utc).isoformat()

        try:
            cursor.execute("""
                INSERT INTO token_metadata
                (workspace, provider, credential_name, expires_at, created_at, storage_type, token_enabled)
                VALUES (?, ?, ?, ?, ?, ?, 1)
                ON CONFLICT(workspace, provider, credential_name) DO UPDATE SET
                    expires_at = excluded.expires_at,
                    storage_type = excluded.storage_type,
                    token_enabled = 1
            """, (workspace, provider, credential_name, expires_at_str, now, storage_type))

            conn.commit()
            return True

        except sqlite3.Error as e:
            logger.error(f"Failed to store token metadata: {e}")
            return False
        finally:
            conn.close()

    def get_token(
        self,
        workspace: str,
        provider: str,
        credential_name: str
    ) -> Optional[Dict[str, Any]]:
        """
        Get a cached token if valid.

        Returns:
            Token data dict if valid, None if expired or not found
        """
        # Check if token mode is enabled
        if not self.is_token_enabled(workspace, provider, credential_name):
            return None

        # Check expiration from metadata
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()

        cursor.execute("""
            SELECT expires_at, storage_type FROM token_metadata
            WHERE workspace = ? AND provider = ? AND credential_name = ?
        """, (workspace, provider, credential_name))

        row = cursor.fetchone()
        conn.close()

        if not row:
            return None

        expires_at_str, storage_type = row

        # Parse expiration time
        try:
            expires_at = datetime.fromisoformat(expires_at_str)
            if expires_at.tzinfo is None:
                expires_at = expires_at.replace(tzinfo=timezone.utc)
        except Exception:
            return None

        # Check if token is expired (with buffer for refresh)
        now = datetime.now(timezone.utc)
        if (expires_at - now).total_seconds() < TOKEN_REFRESH_BUFFER_SECONDS:
            logger.debug(f"Token expired or near expiry: {workspace}/{provider}/{credential_name}")
            return None

        # Retrieve token from storage
        cache_key = self._get_cache_key(workspace, provider, credential_name)

        if storage_type == 'keyring' and self._keyring_available:
            try:
                import keyring
                token_json = keyring.get_password("nubiferos", cache_key)
                if token_json:
                    return json.loads(token_json)
            except Exception as e:
                logger.warning(f"Failed to retrieve from keyring: {e}")

        # Try encrypted file
        file_path = self._get_file_path(workspace, provider, credential_name)
        if file_path.exists():
            try:
                encrypted = file_path.read_bytes()
                return self._decrypt_token(encrypted)
            except Exception as e:
                logger.warning(f"Failed to read encrypted token file: {e}")

        return None

    def clear_token(self, workspace: str, provider: str, credential_name: str) -> bool:
        """Clear a cached token"""
        cache_key = self._get_cache_key(workspace, provider, credential_name)

        # Remove from keyring
        if self._keyring_available:
            try:
                import keyring
                keyring.delete_password("nubiferos", cache_key)
            except Exception:
                pass  # Ignore if not found

        # Remove encrypted file
        file_path = self._get_file_path(workspace, provider, credential_name)
        if file_path.exists():
            try:
                file_path.unlink()
            except Exception as e:
                logger.warning(f"Failed to delete token file: {e}")

        # Remove metadata
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()

        cursor.execute("""
            DELETE FROM token_metadata
            WHERE workspace = ? AND provider = ? AND credential_name = ?
        """, (workspace, provider, credential_name))

        conn.commit()
        conn.close()

        logger.info(f"Cleared token cache: {workspace}/{provider}/{credential_name}")
        return True

    def cleanup_expired(self) -> int:
        """Remove all expired tokens. Returns count of removed tokens."""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()

        now = datetime.now(timezone.utc).isoformat()

        # Find expired tokens
        cursor.execute("""
            SELECT workspace, provider, credential_name FROM token_metadata
            WHERE expires_at < ?
        """, (now,))

        expired = cursor.fetchall()
        conn.close()

        # Clear each expired token
        for workspace, provider, credential_name in expired:
            self.clear_token(workspace, provider, credential_name)

        if expired:
            logger.info(f"Cleaned up {len(expired)} expired tokens")

        return len(expired)

    def enable_token_mode(
        self,
        workspace: str,
        provider: str,
        credential_name: str,
        duration_seconds: int = 3600
    ) -> bool:
        """Enable token mode for a credential"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()

        now = datetime.now(timezone.utc).isoformat()

        try:
            cursor.execute("""
                INSERT INTO token_settings
                (workspace, provider, credential_name, enabled, duration_seconds, created_at, updated_at)
                VALUES (?, ?, ?, 1, ?, ?, ?)
                ON CONFLICT(workspace, provider, credential_name) DO UPDATE SET
                    enabled = 1,
                    duration_seconds = excluded.duration_seconds,
                    updated_at = excluded.updated_at
            """, (workspace, provider, credential_name, duration_seconds, now, now))

            conn.commit()
            logger.info(f"Enabled token mode: {workspace}/{provider}/{credential_name}")
            return True

        except sqlite3.Error as e:
            logger.error(f"Failed to enable token mode: {e}")
            return False
        finally:
            conn.close()

    def disable_token_mode(self, workspace: str, provider: str, credential_name: str) -> bool:
        """Disable token mode for a credential"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()

        now = datetime.now(timezone.utc).isoformat()

        try:
            cursor.execute("""
                UPDATE token_settings SET enabled = 0, updated_at = ?
                WHERE workspace = ? AND provider = ? AND credential_name = ?
            """, (now, workspace, provider, credential_name))

            conn.commit()

            # Also clear any cached token
            self.clear_token(workspace, provider, credential_name)

            logger.info(f"Disabled token mode: {workspace}/{provider}/{credential_name}")
            return True

        except sqlite3.Error as e:
            logger.error(f"Failed to disable token mode: {e}")
            return False
        finally:
            conn.close()

    def is_token_enabled(self, workspace: str, provider: str, credential_name: str) -> bool:
        """Check if token mode is enabled for a credential"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()

        cursor.execute("""
            SELECT enabled FROM token_settings
            WHERE workspace = ? AND provider = ? AND credential_name = ?
        """, (workspace, provider, credential_name))

        row = cursor.fetchone()
        conn.close()

        return bool(row and row[0])

    def get_token_settings(
        self,
        workspace: str,
        provider: str,
        credential_name: str
    ) -> Optional[Dict[str, Any]]:
        """Get token mode settings for a credential"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()

        cursor.execute("""
            SELECT enabled, duration_seconds, created_at, updated_at
            FROM token_settings
            WHERE workspace = ? AND provider = ? AND credential_name = ?
        """, (workspace, provider, credential_name))

        row = cursor.fetchone()

        if not row:
            conn.close()
            return None

        settings = {
            'enabled': bool(row[0]),
            'duration_seconds': row[1],
            'created_at': row[2],
            'updated_at': row[3]
        }

        # Get cached token info if available
        cursor.execute("""
            SELECT expires_at, storage_type FROM token_metadata
            WHERE workspace = ? AND provider = ? AND credential_name = ?
        """, (workspace, provider, credential_name))

        token_row = cursor.fetchone()
        conn.close()

        if token_row:
            settings['token_expires_at'] = token_row[0]
            settings['storage_type'] = token_row[1]

            # Calculate remaining time
            try:
                expires_at = datetime.fromisoformat(token_row[0])
                if expires_at.tzinfo is None:
                    expires_at = expires_at.replace(tzinfo=timezone.utc)
                remaining = (expires_at - datetime.now(timezone.utc)).total_seconds()
                settings['token_remaining_seconds'] = max(0, int(remaining))
            except Exception:
                settings['token_remaining_seconds'] = 0

        return settings

    def get_duration_seconds(self, workspace: str, provider: str, credential_name: str) -> int:
        """Get configured token duration for a credential"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()

        cursor.execute("""
            SELECT duration_seconds FROM token_settings
            WHERE workspace = ? AND provider = ? AND credential_name = ?
        """, (workspace, provider, credential_name))

        row = cursor.fetchone()
        conn.close()

        return row[0] if row else 3600  # Default 1 hour
