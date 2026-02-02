"""Shared test fixtures for NubiferOS CLI tests."""

import pytest
from pathlib import Path
from typer.testing import CliRunner


@pytest.fixture
def runner():
    """Create a CLI test runner."""
    return CliRunner()


@pytest.fixture
def temp_config_dir(tmp_path):
    """Create temporary config directory for isolated tests."""
    config_dir = tmp_path / ".config" / "nubifer"
    config_dir.mkdir(parents=True)
    (config_dir / "workspaces").mkdir()
    return config_dir


@pytest.fixture
def mock_pass_store(tmp_path):
    """Create mock pass store for credential tests."""
    pass_dir = tmp_path / ".password-store"
    pass_dir.mkdir()
    (pass_dir / ".gpg-id").write_text("test@example.com")
    return pass_dir
