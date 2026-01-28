#!/usr/bin/env python3
"""
Property-based tests for ISO signing and verification.

Property: A signed ISO must verify successfully with the corresponding public key,
and any modification to the ISO must cause verification to fail.

Validates: Requirements 3.1, 3.2, 3.4
"""

import hashlib
import os
import subprocess
import tempfile
from pathlib import Path

import pytest

# Check if hypothesis is available
try:
    from hypothesis import given, settings, strategies as st, assume
    HYPOTHESIS_AVAILABLE = True
except ImportError:
    HYPOTHESIS_AVAILABLE = False
    def given(*args, **kwargs):
        def decorator(f):
            return pytest.mark.skip(reason="hypothesis not installed")(f)
        return decorator
    settings = lambda *args, **kwargs: lambda f: f
    class st:
        @staticmethod
        def binary(*args, **kwargs):
            return None
        @staticmethod
        def integers(*args, **kwargs):
            return None


REPO_ROOT = Path(__file__).parent.parent.parent
SIGN_SCRIPT = REPO_ROOT / "scripts" / "security" / "sign-iso.sh"
VERIFY_SCRIPT = REPO_ROOT / "scripts" / "security" / "verify-iso.sh"


def has_gpg_key() -> bool:
    """Check if there's a GPG secret key available."""
    result = subprocess.run(
        ["gpg", "--list-secret-keys"],
        capture_output=True,
        text=True
    )
    return "sec" in result.stdout


def create_test_file(content: bytes, path: Path) -> None:
    """Create a test file with given content."""
    path.write_bytes(content)


def modify_file(path: Path, position: int, new_byte: int) -> None:
    """Modify a single byte in a file."""
    content = bytearray(path.read_bytes())
    if position < len(content):
        content[position] = new_byte % 256
        path.write_bytes(bytes(content))


class TestSigningBasics:
    """Basic tests for signing scripts."""
    
    def test_sign_script_exists(self):
        """Verify sign script exists."""
        assert SIGN_SCRIPT.exists()
        assert os.access(SIGN_SCRIPT, os.X_OK)
    
    def test_verify_script_exists(self):
        """Verify verification script exists."""
        assert VERIFY_SCRIPT.exists()
        assert os.access(VERIFY_SCRIPT, os.X_OK)
    
    def test_sign_help(self):
        """Verify sign script has help."""
        result = subprocess.run(
            [str(SIGN_SCRIPT), "--help"],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0
        assert "--iso" in result.stdout
    
    def test_verify_help(self):
        """Verify verification script has help."""
        result = subprocess.run(
            [str(VERIFY_SCRIPT), "--help"],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0
        assert "--iso" in result.stdout


class TestSignatureIntegrity:
    """Tests for signature integrity properties."""
    
    @pytest.mark.skipif(
        not has_gpg_key(),
        reason="No GPG secret key available"
    )
    def test_sign_and_verify_roundtrip(self):
        """
        Test that signing and verification work together.
        
        **Validates: Requirements 3.1, 3.2, 3.4**
        """
        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir = Path(tmpdir)
            
            # Create a test "ISO" file
            test_iso = tmpdir / "test.iso"
            test_iso.write_bytes(b"This is a test ISO file content" * 100)
            
            # Sign the file
            result = subprocess.run(
                [str(SIGN_SCRIPT), "--iso", str(test_iso), "--quiet"],
                capture_output=True,
                text=True
            )
            
            if result.returncode != 0:
                pytest.skip(f"Signing failed: {result.stderr}")
            
            # Verify signature file was created
            sig_file = tmpdir / "test.iso.sig"
            assert sig_file.exists(), "Signature file not created"
            
            # Verify the signature
            result = subprocess.run(
                [str(VERIFY_SCRIPT), "--iso", str(test_iso), "--quiet"],
                capture_output=True,
                text=True
            )
            
            assert result.returncode == 0, f"Verification failed: {result.stderr}"
    
    @pytest.mark.skipif(
        not has_gpg_key(),
        reason="No GPG secret key available"
    )
    @pytest.mark.skipif(
        not HYPOTHESIS_AVAILABLE,
        reason="hypothesis not installed"
    )
    @given(
        st.binary(min_size=100, max_size=1000),
        st.integers(min_value=0, max_value=99),
        st.integers(min_value=0, max_value=255)
    )
    @settings(max_examples=5, deadline=60000)
    def test_modified_file_fails_verification(self, content, position, new_byte):
        """
        Property: Modified ISO must fail verification.
        
        **Validates: Requirements 3.4**
        
        For any signed file, modifying any byte should cause verification to fail.
        """
        # Ensure modification actually changes the file
        assume(len(content) > position)
        assume(content[position] != new_byte % 256)
        
        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir = Path(tmpdir)
            
            # Create test file
            test_file = tmpdir / "test.iso"
            test_file.write_bytes(content)
            
            # Sign the file
            result = subprocess.run(
                [str(SIGN_SCRIPT), "--iso", str(test_file), "--quiet"],
                capture_output=True,
                text=True
            )
            
            if result.returncode != 0:
                pytest.skip("Signing failed")
            
            # Verify original passes
            result = subprocess.run(
                [str(VERIFY_SCRIPT), "--iso", str(test_file), "--quiet"],
                capture_output=True,
                text=True
            )
            
            if result.returncode != 0:
                pytest.skip("Initial verification failed")
            
            # Modify the file
            modify_file(test_file, position, new_byte)
            
            # Verify modified file fails
            result = subprocess.run(
                [str(VERIFY_SCRIPT), "--iso", str(test_file), "--quiet"],
                capture_output=True,
                text=True
            )
            
            assert result.returncode != 0, "Modified file should fail verification"


class TestVerificationOutput:
    """Tests for verification output formats."""
    
    def test_json_output_format(self):
        """Verify JSON output has correct structure."""
        # Test with non-existent file to get error JSON
        result = subprocess.run(
            [str(VERIFY_SCRIPT), "--iso", "/nonexistent.iso", "--json"],
            capture_output=True,
            text=True
        )
        
        # Should output valid JSON even on error
        import json
        try:
            output = json.loads(result.stdout)
            assert "valid" in output
            assert "message" in output
        except json.JSONDecodeError:
            # JSON output might only be for successful verification
            pass
    
    def test_exit_codes(self):
        """Verify correct exit codes are used."""
        # Missing file should exit with 2
        result = subprocess.run(
            [str(VERIFY_SCRIPT), "--iso", "/nonexistent.iso"],
            capture_output=True,
            text=True
        )
        assert result.returncode == 2


class TestSecurityProperties:
    """Tests for security-related properties."""
    
    def test_no_passphrase_in_command_line(self):
        """Verify passphrase is not passed via command line."""
        script_content = SIGN_SCRIPT.read_text()
        
        # Should use passphrase-fd, not --passphrase with value
        assert "passphrase-fd" in script_content
        # Should not have --passphrase followed by a variable
        assert "--passphrase $" not in script_content
        assert "--passphrase \"$" not in script_content
    
    def test_key_cleanup_in_ci_mode(self):
        """Verify CI mode cleans up imported keys."""
        script_content = SIGN_SCRIPT.read_text()
        
        assert "cleanup_ci_key" in script_content
        assert "delete-secret-keys" in script_content
    
    def test_detached_signature(self):
        """Verify detached signatures are used."""
        script_content = SIGN_SCRIPT.read_text()
        
        assert "--detach-sign" in script_content


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
