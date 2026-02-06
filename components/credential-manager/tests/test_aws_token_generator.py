#!/usr/bin/env python3
"""
Unit tests for AWSTokenGenerator
"""

import os
import sys
import unittest
from datetime import datetime, timezone, timedelta
from unittest.mock import patch, MagicMock

# Add src to path
sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'src'))

from token_generators.aws import (
    AWSTokenGenerator,
    AWSTokenGeneratorError,
    DEFAULT_DURATION_SECONDS,
    MIN_DURATION_SECONDS,
    MAX_DURATION_SECONDS
)


class TestAWSTokenGenerator(unittest.TestCase):
    """Tests for AWSTokenGenerator class"""

    def setUp(self):
        """Set up test fixtures"""
        self.generator = AWSTokenGenerator(workspace="test-workspace")

    @patch.object(AWSTokenGenerator, '_get_base_credentials')
    def test_get_session_token_success(self, mock_get_creds):
        """Test successful session token generation"""
        # Mock base credentials
        mock_get_creds.return_value = {
            'access_key_id': 'AKIATEST123',
            'secret_access_key': 'testsecret'
        }

        # Mock boto3 STS response
        mock_sts_client = MagicMock()
        expiration = datetime.now(timezone.utc) + timedelta(hours=1)
        mock_sts_client.get_session_token.return_value = {
            'Credentials': {
                'AccessKeyId': 'ASIATEMP123',
                'SecretAccessKey': 'tempsecret',
                'SessionToken': 'temptoken',
                'Expiration': expiration
            }
        }

        # Create mock boto3 module
        mock_boto3 = MagicMock()
        mock_boto3.client.return_value = mock_sts_client

        with patch.dict('sys.modules', {'boto3': mock_boto3}):
            generator = AWSTokenGenerator(workspace="test")
            generator._boto3_available = True

            token_data, exp = generator.get_session_token("test-cred")

            self.assertIsNotNone(token_data)
            self.assertEqual(token_data['AccessKeyId'], 'ASIATEMP123')
            self.assertEqual(token_data['SecretAccessKey'], 'tempsecret')
            self.assertEqual(token_data['SessionToken'], 'temptoken')
            self.assertIsNotNone(exp)

    @patch.object(AWSTokenGenerator, '_get_base_credentials')
    def test_get_session_token_no_boto3(self, mock_get_creds):
        """Test error when boto3 is not available"""
        generator = AWSTokenGenerator(workspace="test")
        generator._boto3_available = False

        with self.assertRaises(AWSTokenGeneratorError) as ctx:
            generator.get_session_token("test-cred")

        self.assertIn("boto3", str(ctx.exception))

    def test_get_session_token_no_base_creds(self):
        """Test error when base credentials are not found"""
        generator = AWSTokenGenerator(workspace="test")
        generator._boto3_available = True

        with patch.object(generator, '_get_base_credentials', return_value=None):
            with self.assertRaises(AWSTokenGeneratorError) as ctx:
                generator.get_session_token("nonexistent-cred")

            self.assertIn("Could not retrieve base credentials", str(ctx.exception))

    @patch.object(AWSTokenGenerator, '_get_base_credentials')
    def test_get_session_token_duration_validation(self, mock_get_creds):
        """Test that duration is clamped to valid range"""
        mock_get_creds.return_value = {
            'access_key_id': 'AKIATEST123',
            'secret_access_key': 'testsecret'
        }

        mock_sts_client = MagicMock()
        expiration = datetime.now(timezone.utc) + timedelta(hours=1)
        mock_sts_client.get_session_token.return_value = {
            'Credentials': {
                'AccessKeyId': 'ASIATEMP123',
                'SecretAccessKey': 'tempsecret',
                'SessionToken': 'temptoken',
                'Expiration': expiration
            }
        }

        mock_boto3 = MagicMock()
        mock_boto3.client.return_value = mock_sts_client

        with patch.dict('sys.modules', {'boto3': mock_boto3}):
            generator = AWSTokenGenerator(workspace="test")
            generator._boto3_available = True

            # Test with duration below minimum
            generator.get_session_token("test-cred", duration_seconds=100)
            call_args = mock_sts_client.get_session_token.call_args
            self.assertEqual(call_args[1]['DurationSeconds'], MIN_DURATION_SECONDS)

            # Test with duration above maximum
            mock_sts_client.reset_mock()
            generator.get_session_token("test-cred", duration_seconds=100000)
            call_args = mock_sts_client.get_session_token.call_args
            self.assertEqual(call_args[1]['DurationSeconds'], MAX_DURATION_SECONDS)

    @patch.object(AWSTokenGenerator, '_get_base_credentials')
    def test_assume_role_success(self, mock_get_creds):
        """Test successful role assumption"""
        mock_get_creds.return_value = {
            'access_key_id': 'AKIATEST123',
            'secret_access_key': 'testsecret'
        }

        mock_sts_client = MagicMock()
        expiration = datetime.now(timezone.utc) + timedelta(hours=1)
        mock_sts_client.assume_role.return_value = {
            'Credentials': {
                'AccessKeyId': 'ASIAROLE123',
                'SecretAccessKey': 'rolesecret',
                'SessionToken': 'roletoken',
                'Expiration': expiration
            }
        }

        mock_boto3 = MagicMock()
        mock_boto3.client.return_value = mock_sts_client

        with patch.dict('sys.modules', {'boto3': mock_boto3}):
            generator = AWSTokenGenerator(workspace="test")
            generator._boto3_available = True

            token_data, exp = generator.assume_role(
                "test-cred",
                role_arn="arn:aws:iam::123456789012:role/TestRole"
            )

            self.assertIsNotNone(token_data)
            self.assertEqual(token_data['AccessKeyId'], 'ASIAROLE123')

            # Verify assume_role was called with correct params
            call_args = mock_sts_client.assume_role.call_args
            self.assertEqual(call_args[1]['RoleArn'], 'arn:aws:iam::123456789012:role/TestRole')

    @patch.object(AWSTokenGenerator, '_get_base_credentials')
    def test_assume_role_with_external_id(self, mock_get_creds):
        """Test role assumption with external ID"""
        mock_get_creds.return_value = {
            'access_key_id': 'AKIATEST123',
            'secret_access_key': 'testsecret'
        }

        mock_sts_client = MagicMock()
        expiration = datetime.now(timezone.utc) + timedelta(hours=1)
        mock_sts_client.assume_role.return_value = {
            'Credentials': {
                'AccessKeyId': 'ASIAROLE123',
                'SecretAccessKey': 'rolesecret',
                'SessionToken': 'roletoken',
                'Expiration': expiration
            }
        }

        mock_boto3 = MagicMock()
        mock_boto3.client.return_value = mock_sts_client

        with patch.dict('sys.modules', {'boto3': mock_boto3}):
            generator = AWSTokenGenerator(workspace="test")
            generator._boto3_available = True

            generator.assume_role(
                "test-cred",
                role_arn="arn:aws:iam::123456789012:role/TestRole",
                external_id="my-external-id"
            )

            # Verify external ID was passed
            call_args = mock_sts_client.assume_role.call_args
            self.assertEqual(call_args[1]['ExternalId'], 'my-external-id')

    @patch.object(AWSTokenGenerator, '_get_base_credentials')
    def test_get_caller_identity(self, mock_get_creds):
        """Test get caller identity"""
        mock_get_creds.return_value = {
            'access_key_id': 'AKIATEST123',
            'secret_access_key': 'testsecret'
        }

        mock_sts_client = MagicMock()
        mock_sts_client.get_caller_identity.return_value = {
            'Account': '123456789012',
            'Arn': 'arn:aws:iam::123456789012:user/testuser',
            'UserId': 'AIDATEST123'
        }

        mock_boto3 = MagicMock()
        mock_boto3.client.return_value = mock_sts_client

        with patch.dict('sys.modules', {'boto3': mock_boto3}):
            generator = AWSTokenGenerator(workspace="test")
            generator._boto3_available = True

            identity = generator.get_caller_identity("test-cred")

            self.assertIsNotNone(identity)
            self.assertEqual(identity['Account'], '123456789012')
            self.assertEqual(identity['UserId'], 'AIDATEST123')

    def test_default_duration(self):
        """Test default duration constant"""
        self.assertEqual(DEFAULT_DURATION_SECONDS, 3600)

    def test_duration_limits(self):
        """Test duration limit constants"""
        self.assertEqual(MIN_DURATION_SECONDS, 900)
        self.assertEqual(MAX_DURATION_SECONDS, 43200)


class TestAWSTokenGeneratorErrors(unittest.TestCase):
    """Tests for error handling in AWSTokenGenerator"""

    @patch.object(AWSTokenGenerator, '_get_base_credentials')
    def test_expired_token_error(self, mock_get_creds):
        """Test handling of ExpiredTokenException"""
        mock_get_creds.return_value = {
            'access_key_id': 'AKIATEST123',
            'secret_access_key': 'testsecret'
        }

        mock_sts_client = MagicMock()
        mock_sts_client.get_session_token.side_effect = Exception("ExpiredTokenException: Token has expired")

        mock_boto3 = MagicMock()
        mock_boto3.client.return_value = mock_sts_client

        with patch.dict('sys.modules', {'boto3': mock_boto3}):
            generator = AWSTokenGenerator(workspace="test")
            generator._boto3_available = True

            with self.assertRaises(AWSTokenGeneratorError) as ctx:
                generator.get_session_token("test-cred")

            self.assertIn("expired", str(ctx.exception).lower())

    @patch.object(AWSTokenGenerator, '_get_base_credentials')
    def test_invalid_access_key_error(self, mock_get_creds):
        """Test handling of InvalidClientTokenId"""
        mock_get_creds.return_value = {
            'access_key_id': 'AKIATEST123',
            'secret_access_key': 'testsecret'
        }

        mock_sts_client = MagicMock()
        mock_sts_client.get_session_token.side_effect = Exception("InvalidClientTokenId: Invalid token")

        mock_boto3 = MagicMock()
        mock_boto3.client.return_value = mock_sts_client

        with patch.dict('sys.modules', {'boto3': mock_boto3}):
            generator = AWSTokenGenerator(workspace="test")
            generator._boto3_available = True

            with self.assertRaises(AWSTokenGeneratorError) as ctx:
                generator.get_session_token("test-cred")

            self.assertIn("Invalid AWS access key ID", str(ctx.exception))

    @patch.object(AWSTokenGenerator, '_get_base_credentials')
    def test_signature_mismatch_error(self, mock_get_creds):
        """Test handling of SignatureDoesNotMatch"""
        mock_get_creds.return_value = {
            'access_key_id': 'AKIATEST123',
            'secret_access_key': 'testsecret'
        }

        mock_sts_client = MagicMock()
        mock_sts_client.get_session_token.side_effect = Exception("SignatureDoesNotMatch: Wrong signature")

        mock_boto3 = MagicMock()
        mock_boto3.client.return_value = mock_sts_client

        with patch.dict('sys.modules', {'boto3': mock_boto3}):
            generator = AWSTokenGenerator(workspace="test")
            generator._boto3_available = True

            with self.assertRaises(AWSTokenGeneratorError) as ctx:
                generator.get_session_token("test-cred")

            self.assertIn("Invalid AWS secret access key", str(ctx.exception))


if __name__ == '__main__':
    unittest.main()
