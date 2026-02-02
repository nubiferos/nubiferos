"""Tests for common library utilities."""

import io
import sys
from unittest.mock import patch

import pytest
from hypothesis import given, strategies as st, settings

from nubifer_cli.lib.common import (
    PREFIX_SUCCESS,
    PREFIX_ERROR,
    PREFIX_WARN,
    PREFIX_INFO,
    ExitCode,
    success,
    error,
    warn,
    info,
    safe_error,
    validate_provider,
    get_valid_providers,
)


class TestMessagePrefixes:
    """
    # Feature: nubifer-unified-cli, Property 18: Consistent Message Prefixes
    For any successful operation, the output SHALL contain the "✓" prefix,
    and for any error condition, the output SHALL contain the "✗" prefix.
    **Validates: Requirements 8.1, 8.2**
    """

    def test_success_prefix_is_checkmark(self):
        """Success messages use checkmark prefix."""
        assert PREFIX_SUCCESS == "✓"

    def test_error_prefix_is_x(self):
        """Error messages use X prefix."""
        assert PREFIX_ERROR == "✗"

    def test_warn_prefix_is_warning(self):
        """Warning messages use warning prefix."""
        assert PREFIX_WARN == "⚠"

    def test_info_prefix_is_info(self):
        """Info messages use info prefix."""
        assert PREFIX_INFO == "ℹ"

    @given(message=st.text(min_size=1, max_size=100))
    @settings(max_examples=100)
    def test_success_output_contains_checkmark(self, message):
        """
        # Feature: nubifer-unified-cli, Property 18: Consistent Message Prefixes
        For any message, success() output SHALL contain the "✓" prefix.
        """
        with patch('nubifer_cli.lib.common.console') as mock_console:
            success(message)
            call_args = mock_console.print.call_args
            output = call_args[0][0]
            assert PREFIX_SUCCESS in output

    @given(message=st.text(min_size=1, max_size=100))
    @settings(max_examples=100)
    def test_error_output_contains_x(self, message):
        """
        # Feature: nubifer-unified-cli, Property 18: Consistent Message Prefixes
        For any message, error() output SHALL contain the "✗" prefix.
        """
        with patch('nubifer_cli.lib.common.console') as mock_console:
            error(message)
            call_args = mock_console.print.call_args
            output = call_args[0][0]
            assert PREFIX_ERROR in output


class TestExitCodes:
    """Test exit code consistency."""

    def test_success_exit_code_is_zero(self):
        """Success exit code is 0."""
        assert ExitCode.SUCCESS == 0

    def test_error_exit_code_is_one(self):
        """General error exit code is 1."""
        assert ExitCode.ERROR == 1

    def test_critical_security_exit_code_is_two(self):
        """Critical security exit code is 2."""
        assert ExitCode.CRITICAL_SECURITY == 2


class TestSafeError:
    """Test credential sanitization in error messages."""

    def test_redacts_aws_access_key(self):
        """AWS access keys are redacted."""
        message = "Error with key AKIAIOSFODNN7EXAMPLE"
        result = safe_error(message)
        assert "AKIAIOSFODNN7EXAMPLE" not in result
        assert "[AWS_ACCESS_KEY_REDACTED]" in result

    def test_redacts_guid(self):
        """Azure GUIDs are redacted."""
        message = "Error with tenant 12345678-1234-1234-1234-123456789abc"
        result = safe_error(message)
        assert "12345678-1234-1234-1234-123456789abc" not in result
        assert "[GUID_REDACTED]" in result

    def test_preserves_normal_text(self):
        """Normal text is preserved."""
        message = "Error: workspace not found"
        result = safe_error(message)
        assert result == message

    @given(message=st.text(min_size=1, max_size=200))
    @settings(max_examples=100)
    def test_safe_error_never_crashes(self, message):
        """safe_error should handle any input without crashing."""
        result = safe_error(message)
        assert isinstance(result, str)


class TestProviderValidation:
    """Test provider validation."""

    @pytest.mark.parametrize("provider", ["aws", "azure", "gcp", "oracle", "multi"])
    def test_valid_providers_accepted(self, provider):
        """Valid providers are accepted."""
        assert validate_provider(provider) is True

    @pytest.mark.parametrize("provider", ["AWS", "Azure", "GCP", "ORACLE", "MULTI"])
    def test_valid_providers_case_insensitive(self, provider):
        """Provider validation is case-insensitive."""
        assert validate_provider(provider) is True

    @pytest.mark.parametrize("provider", ["invalid", "amazon", "google", "microsoft", ""])
    def test_invalid_providers_rejected(self, provider):
        """Invalid providers are rejected."""
        assert validate_provider(provider) is False

    def test_get_valid_providers_returns_all(self):
        """get_valid_providers returns all valid providers."""
        providers = get_valid_providers()
        assert "aws" in providers
        assert "azure" in providers
        assert "gcp" in providers
        assert "oracle" in providers
        assert "multi" in providers
        assert len(providers) == 5
