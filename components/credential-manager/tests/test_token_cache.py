#!/usr/bin/env python3
"""
Unit tests for TokenCache
"""

import os
import sys
import json
import tempfile
import unittest
from datetime import datetime, timezone, timedelta
from pathlib import Path
from unittest.mock import patch, MagicMock

# Add src to path
sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'src'))

from token_cache import TokenCache, TokenCacheError


class TestTokenCache(unittest.TestCase):
    """Tests for TokenCache class"""

    def setUp(self):
        """Set up test fixtures"""
        # Create temp directory for test database
        self.temp_dir = tempfile.mkdtemp()
        self.db_path = Path(self.temp_dir) / "test_token_cache.db"

        # TokenCache is file-based only (keyring support removed in 3e937cc);
        # no keyring mocking needed.
        self.cache = TokenCache(db_path=self.db_path)

    def tearDown(self):
        """Clean up test fixtures"""
        # Clean up temp files
        import shutil
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def test_init_creates_database(self):
        """Test that initialization creates the database"""
        self.assertTrue(self.db_path.exists())

    def test_enable_token_mode(self):
        """Test enabling token mode"""
        result = self.cache.enable_token_mode("test-ws", "aws", "test-cred", duration_seconds=1800)
        self.assertTrue(result)

        # Verify it's enabled
        self.assertTrue(self.cache.is_token_enabled("test-ws", "aws", "test-cred"))

    def test_disable_token_mode(self):
        """Test disabling token mode"""
        # Enable first
        self.cache.enable_token_mode("test-ws", "aws", "test-cred")
        self.assertTrue(self.cache.is_token_enabled("test-ws", "aws", "test-cred"))

        # Disable
        result = self.cache.disable_token_mode("test-ws", "aws", "test-cred")
        self.assertTrue(result)
        self.assertFalse(self.cache.is_token_enabled("test-ws", "aws", "test-cred"))

    def test_is_token_enabled_returns_false_when_not_configured(self):
        """Test is_token_enabled returns False for unconfigured credentials"""
        self.assertFalse(self.cache.is_token_enabled("unknown-ws", "aws", "unknown-cred"))

    def test_store_and_get_token(self):
        """Test storing and retrieving tokens"""
        # Enable token mode first
        self.cache.enable_token_mode("test-ws", "aws", "test-cred")

        # Store a token
        token_data = {
            'AccessKeyId': 'AKIATEST123',
            'SecretAccessKey': 'testsecret123',
            'SessionToken': 'testsessiontoken123'
        }
        expires_at = datetime.now(timezone.utc) + timedelta(hours=1)

        result = self.cache.store_token("test-ws", "aws", "test-cred", token_data, expires_at)
        self.assertTrue(result)

        # Retrieve the token
        retrieved = self.cache.get_token("test-ws", "aws", "test-cred")
        self.assertIsNotNone(retrieved)
        self.assertEqual(retrieved['AccessKeyId'], 'AKIATEST123')
        self.assertEqual(retrieved['SecretAccessKey'], 'testsecret123')
        self.assertEqual(retrieved['SessionToken'], 'testsessiontoken123')

    def test_get_token_returns_none_when_expired(self):
        """Test that expired tokens return None"""
        self.cache.enable_token_mode("test-ws", "aws", "test-cred")

        token_data = {
            'AccessKeyId': 'AKIATEST123',
            'SecretAccessKey': 'testsecret123',
            'SessionToken': 'testsessiontoken123'
        }
        # Expired 1 hour ago
        expires_at = datetime.now(timezone.utc) - timedelta(hours=1)

        self.cache.store_token("test-ws", "aws", "test-cred", token_data, expires_at)

        # Should return None for expired token
        retrieved = self.cache.get_token("test-ws", "aws", "test-cred")
        self.assertIsNone(retrieved)

    def test_get_token_returns_none_when_near_expiry(self):
        """Test that tokens near expiry (< 5 min) return None for refresh"""
        self.cache.enable_token_mode("test-ws", "aws", "test-cred")

        token_data = {
            'AccessKeyId': 'AKIATEST123',
            'SecretAccessKey': 'testsecret123',
            'SessionToken': 'testsessiontoken123'
        }
        # Expires in 3 minutes (within 5 min buffer)
        expires_at = datetime.now(timezone.utc) + timedelta(minutes=3)

        self.cache.store_token("test-ws", "aws", "test-cred", token_data, expires_at)

        # Should return None to trigger refresh
        retrieved = self.cache.get_token("test-ws", "aws", "test-cred")
        self.assertIsNone(retrieved)

    def test_get_token_returns_none_when_not_enabled(self):
        """Test that get_token returns None when token mode is not enabled"""
        token_data = {
            'AccessKeyId': 'AKIATEST123',
            'SecretAccessKey': 'testsecret123',
            'SessionToken': 'testsessiontoken123'
        }
        expires_at = datetime.now(timezone.utc) + timedelta(hours=1)

        # Store without enabling (shouldn't happen in practice, but test the guard)
        # Note: store_token doesn't check if enabled, but get_token does
        result = self.cache.store_token("test-ws", "aws", "test-cred", token_data, expires_at)
        self.assertTrue(result)

        # get_token should still return None because mode is not enabled
        retrieved = self.cache.get_token("test-ws", "aws", "test-cred")
        self.assertIsNone(retrieved)

    def test_clear_token(self):
        """Test clearing cached tokens"""
        self.cache.enable_token_mode("test-ws", "aws", "test-cred")

        token_data = {
            'AccessKeyId': 'AKIATEST123',
            'SecretAccessKey': 'testsecret123',
            'SessionToken': 'testsessiontoken123'
        }
        expires_at = datetime.now(timezone.utc) + timedelta(hours=1)

        self.cache.store_token("test-ws", "aws", "test-cred", token_data, expires_at)

        # Clear the token
        result = self.cache.clear_token("test-ws", "aws", "test-cred")
        self.assertTrue(result)

        # Token should be gone (but mode still enabled)
        retrieved = self.cache.get_token("test-ws", "aws", "test-cred")
        self.assertIsNone(retrieved)
        self.assertTrue(self.cache.is_token_enabled("test-ws", "aws", "test-cred"))

    def test_get_token_settings(self):
        """Test retrieving token settings"""
        self.cache.enable_token_mode("test-ws", "aws", "test-cred", duration_seconds=7200)

        settings = self.cache.get_token_settings("test-ws", "aws", "test-cred")
        self.assertIsNotNone(settings)
        self.assertTrue(settings['enabled'])
        self.assertEqual(settings['duration_seconds'], 7200)

    def test_get_token_settings_returns_none_when_not_configured(self):
        """Test get_token_settings returns None for unconfigured credentials"""
        settings = self.cache.get_token_settings("unknown-ws", "aws", "unknown-cred")
        self.assertIsNone(settings)

    def test_get_duration_seconds(self):
        """Test getting configured duration"""
        self.cache.enable_token_mode("test-ws", "aws", "test-cred", duration_seconds=1800)
        duration = self.cache.get_duration_seconds("test-ws", "aws", "test-cred")
        self.assertEqual(duration, 1800)

    def test_get_duration_seconds_default(self):
        """Test default duration for unconfigured credentials"""
        duration = self.cache.get_duration_seconds("unknown-ws", "aws", "unknown-cred")
        self.assertEqual(duration, 3600)  # Default 1 hour

    def test_cleanup_expired(self):
        """Test cleanup of expired tokens"""
        self.cache.enable_token_mode("test-ws", "aws", "expired-cred")
        self.cache.enable_token_mode("test-ws", "aws", "valid-cred")

        expired_data = {
            'AccessKeyId': 'EXPIRED',
            'SecretAccessKey': 'secret',
            'SessionToken': 'token'
        }
        valid_data = {
            'AccessKeyId': 'VALID',
            'SecretAccessKey': 'secret',
            'SessionToken': 'token'
        }

        # Store expired token
        self.cache.store_token(
            "test-ws", "aws", "expired-cred", expired_data,
            datetime.now(timezone.utc) - timedelta(hours=1)
        )

        # Store valid token
        self.cache.store_token(
            "test-ws", "aws", "valid-cred", valid_data,
            datetime.now(timezone.utc) + timedelta(hours=1)
        )

        # Run cleanup
        count = self.cache.cleanup_expired()
        self.assertEqual(count, 1)

    def test_workspace_isolation(self):
        """Test that tokens are isolated by workspace"""
        self.cache.enable_token_mode("ws1", "aws", "cred")
        self.cache.enable_token_mode("ws2", "aws", "cred")

        token1 = {
            'AccessKeyId': 'WS1KEY',
            'SecretAccessKey': 'secret',
            'SessionToken': 'token1'
        }
        token2 = {
            'AccessKeyId': 'WS2KEY',
            'SecretAccessKey': 'secret',
            'SessionToken': 'token2'
        }
        expires = datetime.now(timezone.utc) + timedelta(hours=1)

        self.cache.store_token("ws1", "aws", "cred", token1, expires)
        self.cache.store_token("ws2", "aws", "cred", token2, expires)

        # Verify isolation
        retrieved1 = self.cache.get_token("ws1", "aws", "cred")
        retrieved2 = self.cache.get_token("ws2", "aws", "cred")

        self.assertEqual(retrieved1['AccessKeyId'], 'WS1KEY')
        self.assertEqual(retrieved2['AccessKeyId'], 'WS2KEY')


if __name__ == '__main__':
    unittest.main()
