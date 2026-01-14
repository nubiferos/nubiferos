#!/usr/bin/env python3
"""
Pass Backend for NubiferOS Credential Manager
Wraps the 'pass' (password-store) command for secure credential storage.
"""

import subprocess
import os
import json
import logging
from pathlib import Path
from typing import Optional, Dict, List

logger = logging.getLogger(__name__)


class PassBackendError(Exception):
    """Base exception for pass backend errors"""
    pass


class PassNotInitializedError(PassBackendError):
    """Raised when pass store is not initialized"""
    pass


class PassBackend:
    """
    Wrapper for 'pass' (password-store) command.
    Provides secure credential storage using GPG encryption.
    """
    
    PASS_STORE_PREFIX = "nubiferos/credentials"
    
    def __init__(self):
        self.pass_dir = Path.home() / ".password-store"
        self._check_pass_installed()
    
    def _check_pass_installed(self):
        """Check if 'pass' command is available"""
        try:
            subprocess.run(
                ["pass", "version"],
                capture_output=True,
                check=True,
                timeout=5
            )
        except (subprocess.CalledProcessError, FileNotFoundError, subprocess.TimeoutExpired):
            raise PassBackendError(
                "'pass' (password-store) is not installed. "
                "Install with: sudo apt-get install pass"
            )
    
    def is_initialized(self) -> bool:
        """Check if pass store is initialized"""
        return (self.pass_dir / ".gpg-id").exists()
    
    def get_gpg_key_id(self) -> Optional[str]:
        """Get the GPG key ID used for pass store"""
        if not self.is_initialized():
            return None
        
        try:
            gpg_id_file = self.pass_dir / ".gpg-id"
            return gpg_id_file.read_text().strip()
        except Exception as e:
            logger.error(f"Failed to read GPG key ID: {e}")
            return None
    
    def list_gpg_keys(self) -> List[Dict[str, str]]:
        """List available GPG keys"""
        try:
            result = subprocess.run(
                ["gpg", "--list-secret-keys", "--with-colons"],
                capture_output=True,
                text=True,
                check=True,
                timeout=10
            )
            
            keys = []
            current_key = {}
            
            for line in result.stdout.split('\n'):
                if line.startswith('sec:'):
                    parts = line.split(':')
                    current_key = {'keyid': parts[4][-16:]}  # Last 16 chars
                elif line.startswith('uid:') and current_key:
                    parts = line.split(':')
                    current_key['uid'] = parts[9]
                    keys.append(current_key)
                    current_key = {}
            
            return keys
        except Exception as e:
            logger.error(f"Failed to list GPG keys: {e}")
            return []
    
    def initialize(self, gpg_key_id: str):
        """Initialize pass store with GPG key"""
        try:
            subprocess.run(
                ["pass", "init", gpg_key_id],
                capture_output=True,
                check=True,
                timeout=10
            )
            logger.info(f"Initialized pass store with GPG key: {gpg_key_id}")
        except subprocess.CalledProcessError as e:
            raise PassBackendError(f"Failed to initialize pass: {e.stderr.decode()}")
    
    def _get_pass_path(self, provider: str, account_id: str, key_name: str) -> str:
        """Get the pass store path for a credential component"""
        # Sanitize inputs to prevent path traversal
        provider = provider.replace('/', '_').replace('..', '')
        account_id = account_id.replace('/', '_').replace('..', '')
        key_name = key_name.replace('/', '_').replace('..', '')
        
        return f"{self.PASS_STORE_PREFIX}/{provider}/{account_id}/{key_name}"
    
    def store_credential(self, provider: str, account_id: str, key_name: str, value: str):
        """Store a credential component in pass"""
        if not self.is_initialized():
            raise PassNotInitializedError("Pass store not initialized. Run 'pass init <gpg-key-id>' first.")
        
        pass_path = self._get_pass_path(provider, account_id, key_name)
        
        try:
            # Use pass insert with echo to avoid interactive prompt
            process = subprocess.Popen(
                ["pass", "insert", "-m", pass_path],
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )
            
            stdout, stderr = process.communicate(input=f"{value}\n{value}\n", timeout=10)
            
            if process.returncode != 0:
                raise PassBackendError(f"Failed to store credential: {stderr}")
            
            logger.info(f"Stored credential at: {pass_path}")
            
        except subprocess.TimeoutExpired:
            process.kill()
            raise PassBackendError("Timeout while storing credential")
        except Exception as e:
            raise PassBackendError(f"Failed to store credential: {e}")
    
    def retrieve_credential(self, provider: str, account_id: str, key_name: str) -> Optional[str]:
        """Retrieve a credential component from pass"""
        if not self.is_initialized():
            raise PassNotInitializedError("Pass store not initialized")
        
        pass_path = self._get_pass_path(provider, account_id, key_name)
        
        try:
            result = subprocess.run(
                ["pass", "show", pass_path],
                capture_output=True,
                text=True,
                check=True,
                timeout=10
            )
            
            # Return first line (pass stores password on first line)
            return result.stdout.strip().split('\n')[0]
            
        except subprocess.CalledProcessError:
            logger.warning(f"Credential not found: {pass_path}")
            return None
        except subprocess.TimeoutExpired:
            raise PassBackendError("Timeout while retrieving credential")
    
    def delete_credential(self, provider: str, account_id: str, key_name: str):
        """Delete a credential component from pass"""
        if not self.is_initialized():
            raise PassNotInitializedError("Pass store not initialized")
        
        pass_path = self._get_pass_path(provider, account_id, key_name)
        
        try:
            subprocess.run(
                ["pass", "rm", "-f", pass_path],
                capture_output=True,
                check=True,
                timeout=10
            )
            logger.info(f"Deleted credential: {pass_path}")
            
        except subprocess.CalledProcessError as e:
            logger.warning(f"Failed to delete credential {pass_path}: {e}")
    
    def delete_account(self, provider: str, account_id: str):
        """Delete all credentials for an account"""
        if not self.is_initialized():
            raise PassNotInitializedError("Pass store not initialized")
        
        pass_path = f"{self.PASS_STORE_PREFIX}/{provider}/{account_id}"
        
        try:
            subprocess.run(
                ["pass", "rm", "-rf", pass_path],
                capture_output=True,
                check=True,
                timeout=10
            )
            logger.info(f"Deleted account credentials: {pass_path}")
            
        except subprocess.CalledProcessError as e:
            logger.warning(f"Failed to delete account {pass_path}: {e}")
    
    def list_accounts(self, provider: Optional[str] = None) -> List[str]:
        """List all accounts in pass store"""
        if not self.is_initialized():
            return []
        
        base_path = self.PASS_STORE_PREFIX
        if provider:
            base_path = f"{base_path}/{provider}"
        
        try:
            result = subprocess.run(
                ["pass", "ls", base_path],
                capture_output=True,
                text=True,
                timeout=10
            )
            
            # Parse pass ls output to extract account IDs
            accounts = []
            for line in result.stdout.split('\n'):
                # Look for lines with account IDs (directories under provider)
                if '├──' in line or '└──' in line:
                    # Extract directory name
                    parts = line.split('──')
                    if len(parts) > 1:
                        account_id = parts[1].strip()
                        if account_id and not account_id.endswith('.gpg'):
                            accounts.append(account_id)
            
            return accounts
            
        except Exception as e:
            logger.error(f"Failed to list accounts: {e}")
            return []
