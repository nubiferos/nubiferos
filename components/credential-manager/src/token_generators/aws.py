#!/usr/bin/env python3
"""
AWS Token Generator for NubiferOS Credential Manager

Generates temporary STS tokens using base credentials from pass.
"""

import logging
import subprocess
from datetime import datetime, timezone, timedelta
from typing import Optional, Dict, Any, Tuple

logger = logging.getLogger(__name__)

# Default token duration (1 hour)
DEFAULT_DURATION_SECONDS = 3600

# Min/max durations per AWS limits
MIN_DURATION_SECONDS = 900      # 15 minutes
MAX_DURATION_SECONDS = 43200    # 12 hours


class AWSTokenGeneratorError(Exception):
    """Base exception for AWS token generation errors"""
    pass


class AWSTokenGenerator:
    """
    Generates AWS STS temporary credentials.

    Uses base credentials from pass (password-store) to call STS
    and generate temporary session tokens or assume roles.
    """

    def __init__(self, workspace: str = "default"):
        """
        Initialize AWS token generator.

        Args:
            workspace: Workspace ID for credential lookup
        """
        self.workspace = workspace
        self._boto3_available = self._check_boto3()

    def _check_boto3(self) -> bool:
        """Check if boto3 is available"""
        try:
            import boto3
            return True
        except ImportError:
            logger.warning("boto3 not installed, AWS token generation unavailable")
            return False

    def _get_base_credentials(self, credential_name: str) -> Optional[Dict[str, str]]:
        """
        Retrieve base credentials from pass.

        Args:
            credential_name: Credential profile name

        Returns:
            Dict with access_key_id and secret_access_key, or None
        """
        base_path = f"nubifer/{self.workspace}/cloud/aws/{credential_name}"

        try:
            # Get access key
            result = subprocess.run(
                ["pass", "show", f"{base_path}/access-key-id"],
                capture_output=True,
                text=True,
                timeout=10
            )
            if result.returncode != 0:
                logger.error(f"Failed to get access key from pass: {result.stderr}")
                return None
            access_key = result.stdout.strip()

            # Get secret key
            result = subprocess.run(
                ["pass", "show", f"{base_path}/secret-access-key"],
                capture_output=True,
                text=True,
                timeout=10
            )
            if result.returncode != 0:
                logger.error(f"Failed to get secret key from pass: {result.stderr}")
                return None
            secret_key = result.stdout.strip()

            return {
                'access_key_id': access_key,
                'secret_access_key': secret_key
            }

        except subprocess.TimeoutExpired:
            logger.error("Timeout retrieving credentials from pass")
            return None
        except Exception as e:
            logger.error(f"Error retrieving credentials from pass: {e}")
            return None

    def get_session_token(
        self,
        credential_name: str,
        duration_seconds: int = DEFAULT_DURATION_SECONDS,
        serial_number: Optional[str] = None,
        token_code: Optional[str] = None
    ) -> Tuple[Optional[Dict[str, Any]], Optional[datetime]]:
        """
        Get STS session token using GetSessionToken API.

        Args:
            credential_name: Credential profile name
            duration_seconds: Token lifetime (900-43200 seconds)
            serial_number: MFA device ARN (optional)
            token_code: MFA token code (optional, required if serial_number set)

        Returns:
            Tuple of (token_dict, expiration_datetime) or (None, None) on failure
            token_dict contains: AccessKeyId, SecretAccessKey, SessionToken
        """
        if not self._boto3_available:
            raise AWSTokenGeneratorError("boto3 is not installed")

        # Validate duration
        duration_seconds = max(MIN_DURATION_SECONDS, min(MAX_DURATION_SECONDS, duration_seconds))

        # Get base credentials
        base_creds = self._get_base_credentials(credential_name)
        if not base_creds:
            raise AWSTokenGeneratorError(
                f"Could not retrieve base credentials for '{credential_name}' in workspace '{self.workspace}'"
            )

        try:
            import boto3

            # Create STS client with base credentials
            sts_client = boto3.client(
                'sts',
                aws_access_key_id=base_creds['access_key_id'],
                aws_secret_access_key=base_creds['secret_access_key']
            )

            # Build request params
            params = {'DurationSeconds': duration_seconds}

            if serial_number and token_code:
                params['SerialNumber'] = serial_number
                params['TokenCode'] = token_code

            # Call GetSessionToken
            logger.debug(f"Calling STS GetSessionToken for {credential_name}")
            response = sts_client.get_session_token(**params)

            credentials = response['Credentials']

            token_data = {
                'AccessKeyId': credentials['AccessKeyId'],
                'SecretAccessKey': credentials['SecretAccessKey'],
                'SessionToken': credentials['SessionToken']
            }

            # Parse expiration
            expiration = credentials['Expiration']
            if isinstance(expiration, str):
                expiration = datetime.fromisoformat(expiration.replace('Z', '+00:00'))

            logger.info(f"Generated STS session token for {credential_name}, expires {expiration}")

            return token_data, expiration

        except Exception as e:
            error_msg = str(e)
            if 'ExpiredTokenException' in error_msg:
                raise AWSTokenGeneratorError("Base credentials have expired")
            elif 'InvalidClientTokenId' in error_msg:
                raise AWSTokenGeneratorError("Invalid AWS access key ID")
            elif 'SignatureDoesNotMatch' in error_msg:
                raise AWSTokenGeneratorError("Invalid AWS secret access key")
            elif 'AccessDenied' in error_msg:
                raise AWSTokenGeneratorError("Access denied - check IAM permissions")
            else:
                raise AWSTokenGeneratorError(f"STS GetSessionToken failed: {e}")

    def assume_role(
        self,
        credential_name: str,
        role_arn: str,
        role_session_name: str = "nubiferos-session",
        duration_seconds: int = DEFAULT_DURATION_SECONDS,
        external_id: Optional[str] = None,
        serial_number: Optional[str] = None,
        token_code: Optional[str] = None
    ) -> Tuple[Optional[Dict[str, Any]], Optional[datetime]]:
        """
        Assume an IAM role using AssumeRole API.

        Args:
            credential_name: Credential profile name for base credentials
            role_arn: ARN of the role to assume
            role_session_name: Session name for CloudTrail
            duration_seconds: Token lifetime (900-43200 seconds)
            external_id: External ID for cross-account access (optional)
            serial_number: MFA device ARN (optional)
            token_code: MFA token code (optional, required if serial_number set)

        Returns:
            Tuple of (token_dict, expiration_datetime) or (None, None) on failure
            token_dict contains: AccessKeyId, SecretAccessKey, SessionToken
        """
        if not self._boto3_available:
            raise AWSTokenGeneratorError("boto3 is not installed")

        # Validate duration
        duration_seconds = max(MIN_DURATION_SECONDS, min(MAX_DURATION_SECONDS, duration_seconds))

        # Get base credentials
        base_creds = self._get_base_credentials(credential_name)
        if not base_creds:
            raise AWSTokenGeneratorError(
                f"Could not retrieve base credentials for '{credential_name}' in workspace '{self.workspace}'"
            )

        try:
            import boto3

            # Create STS client with base credentials
            sts_client = boto3.client(
                'sts',
                aws_access_key_id=base_creds['access_key_id'],
                aws_secret_access_key=base_creds['secret_access_key']
            )

            # Build request params
            params = {
                'RoleArn': role_arn,
                'RoleSessionName': role_session_name,
                'DurationSeconds': duration_seconds
            }

            if external_id:
                params['ExternalId'] = external_id

            if serial_number and token_code:
                params['SerialNumber'] = serial_number
                params['TokenCode'] = token_code

            # Call AssumeRole
            logger.debug(f"Calling STS AssumeRole for {credential_name} -> {role_arn}")
            response = sts_client.assume_role(**params)

            credentials = response['Credentials']

            token_data = {
                'AccessKeyId': credentials['AccessKeyId'],
                'SecretAccessKey': credentials['SecretAccessKey'],
                'SessionToken': credentials['SessionToken']
            }

            # Parse expiration
            expiration = credentials['Expiration']
            if isinstance(expiration, str):
                expiration = datetime.fromisoformat(expiration.replace('Z', '+00:00'))

            logger.info(f"Assumed role {role_arn} for {credential_name}, expires {expiration}")

            return token_data, expiration

        except Exception as e:
            error_msg = str(e)
            if 'AccessDenied' in error_msg:
                raise AWSTokenGeneratorError(
                    f"Access denied assuming role {role_arn} - check trust policy"
                )
            elif 'MalformedPolicyDocument' in error_msg:
                raise AWSTokenGeneratorError("Invalid role policy")
            else:
                raise AWSTokenGeneratorError(f"STS AssumeRole failed: {e}")

    def get_caller_identity(self, credential_name: str) -> Optional[Dict[str, str]]:
        """
        Get caller identity to verify credentials work.

        Returns:
            Dict with Account, Arn, UserId or None on failure
        """
        if not self._boto3_available:
            return None

        base_creds = self._get_base_credentials(credential_name)
        if not base_creds:
            return None

        try:
            import boto3

            sts_client = boto3.client(
                'sts',
                aws_access_key_id=base_creds['access_key_id'],
                aws_secret_access_key=base_creds['secret_access_key']
            )

            response = sts_client.get_caller_identity()

            return {
                'Account': response['Account'],
                'Arn': response['Arn'],
                'UserId': response['UserId']
            }

        except Exception as e:
            logger.error(f"GetCallerIdentity failed: {e}")
            return None
