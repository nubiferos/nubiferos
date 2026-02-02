#!/usr/bin/env python3
"""Common utilities for the NubiferOS CLI."""

import re
import sys
from enum import IntEnum
from pathlib import Path
from typing import Optional

import typer
from rich.console import Console

console = Console()

# Message prefixes for consistent output
PREFIX_SUCCESS = "✓"
PREFIX_ERROR = "✗"
PREFIX_WARN = "⚠"
PREFIX_INFO = "ℹ"


class ExitCode(IntEnum):
    """Standard exit codes for the CLI."""
    SUCCESS = 0
    ERROR = 1
    CRITICAL_SECURITY = 2


def success(message: str) -> None:
    """Print success message with checkmark prefix."""
    console.print(f"{PREFIX_SUCCESS} {message}", style="green")


def error(message: str, exit_code: Optional[ExitCode] = None) -> None:
    """Print error message with X prefix. Optionally exit with code."""
    console.print(f"{PREFIX_ERROR} {message}", style="red", stderr=True)
    if exit_code is not None:
        sys.exit(exit_code)


def warn(message: str) -> None:
    """Print warning message with warning prefix."""
    console.print(f"{PREFIX_WARN} {message}", style="yellow", stderr=True)


def info(message: str) -> None:
    """Print info message with info prefix."""
    console.print(f"{PREFIX_INFO} {message}", style="blue")


def get_current_workspace_id() -> Optional[str]:
    """Get the current workspace ID from file.
    
    Returns:
        The current workspace ID, or None if not set.
    """
    current_file = Path.home() / ".config" / "nubifer" / "current-workspace"
    
    if not current_file.exists():
        return None
    
    try:
        workspace_id = current_file.read_text().strip()
        return workspace_id if workspace_id else None
    except Exception:
        return None


def get_workspace_config_dir() -> Path:
    """Get the workspace configuration directory."""
    return Path.home() / ".config" / "nubifer" / "workspaces"


def confirm_workspace(workspace_id: str, workspace_name: str) -> bool:
    """Confirm workspace before sensitive operations.
    
    Args:
        workspace_id: The workspace ID.
        workspace_name: The workspace display name.
    
    Returns:
        True if confirmed, False otherwise.
    """
    return typer.confirm(
        f"Confirm operation on workspace '{workspace_name}' ({workspace_id})?"
    )


def safe_error(message: str) -> str:
    """Sanitize error message to remove any credential values.
    
    This function removes patterns that look like credentials:
    - AWS access keys (AKIA...)
    - AWS secret keys (40 char base64)
    - Azure GUIDs
    - Generic API keys
    
    Args:
        message: The error message to sanitize.
    
    Returns:
        The sanitized message with credentials redacted.
    """
    sensitive_patterns = [
        (r'AKIA[0-9A-Z]{16}', '[AWS_ACCESS_KEY_REDACTED]'),
        (r'(?<![A-Za-z0-9/+=])[A-Za-z0-9/+=]{40}(?![A-Za-z0-9/+=])', '[SECRET_REDACTED]'),
        (r'[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}', '[GUID_REDACTED]'),
        (r'(?i)(password|secret|token|key)\s*[=:]\s*\S+', r'\1=[REDACTED]'),
    ]
    
    result = message
    for pattern, replacement in sensitive_patterns:
        result = re.sub(pattern, replacement, result)
    
    return result


def validate_provider(provider: str) -> bool:
    """Validate cloud provider name.
    
    Args:
        provider: The provider name to validate.
    
    Returns:
        True if valid, False otherwise.
    """
    valid_providers = {"aws", "azure", "gcp", "oracle", "multi"}
    return provider.lower() in valid_providers


def get_valid_providers() -> list[str]:
    """Get list of valid cloud providers."""
    return ["aws", "azure", "gcp", "oracle", "multi"]
