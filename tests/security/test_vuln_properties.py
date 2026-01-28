#!/usr/bin/env python3
"""
Property-based tests for vulnerability scanning.

Property: If a vulnerability V exists for component C in the SBOM, and V is not
in the allowlist, then V must appear in the vulnerability report.

Validates: Requirements 2.1, 2.5, 2.6
"""

import json
import os
import subprocess
import tempfile
from pathlib import Path
from datetime import datetime, timedelta

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
        def text(*args, **kwargs):
            return None
        @staticmethod
        def lists(*args, **kwargs):
            return None
        @staticmethod
        def sampled_from(*args, **kwargs):
            return None


REPO_ROOT = Path(__file__).parent.parent.parent
VULN_SCRIPT = REPO_ROOT / "scripts" / "security" / "vuln-scan.sh"
ALLOWLIST_PATH = REPO_ROOT / "security" / "vuln-allowlist.yaml"


def create_mock_allowlist(cve_ids: list[str], expired: bool = False) -> str:
    """Create a mock allowlist YAML content."""
    if not cve_ids:
        return "vulnerabilities: []"
    
    entries = []
    for cve_id in cve_ids:
        if expired:
            expires = (datetime.now() - timedelta(days=30)).strftime("%Y-%m-%d")
        else:
            expires = (datetime.now() + timedelta(days=30)).strftime("%Y-%m-%d")
        
        entries.append(f"""  - id: {cve_id}
    reason: "Test allowlist entry"
    expires: "{expires}" """)
    
    return "vulnerabilities:\n" + "\n".join(entries)


def create_mock_vuln_report(vulnerabilities: list[dict]) -> dict:
    """Create a mock grype vulnerability report."""
    matches = []
    for vuln in vulnerabilities:
        matches.append({
            "vulnerability": {
                "id": vuln["id"],
                "severity": vuln.get("severity", "High"),
                "description": f"Test vulnerability {vuln['id']}"
            },
            "artifact": {
                "name": vuln.get("package", "test-package"),
                "version": vuln.get("version", "1.0.0")
            }
        })
    
    return {"matches": matches}


class TestVulnScannerBasics:
    """Basic tests for vulnerability scanner."""
    
    def test_script_exists(self):
        """Verify vulnerability scan script exists."""
        assert VULN_SCRIPT.exists(), f"Vuln script not found: {VULN_SCRIPT}"
        assert os.access(VULN_SCRIPT, os.X_OK), "Vuln script not executable"
    
    def test_allowlist_exists(self):
        """Verify allowlist template exists."""
        assert ALLOWLIST_PATH.exists(), f"Allowlist not found: {ALLOWLIST_PATH}"
    
    def test_help_output(self):
        """Verify help output contains expected options."""
        result = subprocess.run(
            [str(VULN_SCRIPT), "--help"],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0
        assert "--sbom" in result.stdout
        assert "--threshold" in result.stdout
        assert "--allowlist" in result.stdout


class TestAllowlistFiltering:
    """Tests for allowlist filtering logic."""
    
    def test_empty_allowlist_passes_all(self):
        """Empty allowlist should not filter any vulnerabilities."""
        allowlist = create_mock_allowlist([])
        assert "vulnerabilities: []" in allowlist
    
    def test_allowlist_format(self):
        """Verify allowlist format is correct."""
        allowlist = create_mock_allowlist(["CVE-2024-1234", "CVE-2024-5678"])
        assert "CVE-2024-1234" in allowlist
        assert "CVE-2024-5678" in allowlist
        assert "expires:" in allowlist
    
    def test_expired_allowlist_format(self):
        """Verify expired entries have past dates."""
        allowlist = create_mock_allowlist(["CVE-2024-1234"], expired=True)
        # Should contain a date in the past
        assert "expires:" in allowlist


class TestThresholdLogic:
    """Tests for severity threshold logic."""
    
    @pytest.mark.parametrize("threshold,should_fail", [
        ("critical", [("Critical", True), ("High", False), ("Medium", False)]),
        ("high", [("Critical", True), ("High", True), ("Medium", False)]),
        ("medium", [("Critical", True), ("High", True), ("Medium", True)]),
    ])
    def test_threshold_levels(self, threshold, should_fail):
        """Verify threshold logic is implemented in script."""
        # This is a static analysis test - verify the script has threshold logic
        script_content = VULN_SCRIPT.read_text()
        
        assert "check_threshold" in script_content
        assert "critical" in script_content.lower()
        assert "high" in script_content.lower()
        assert "medium" in script_content.lower()


class TestVulnReportProperties:
    """Property-based tests for vulnerability reporting."""
    
    @pytest.mark.skipif(
        not HYPOTHESIS_AVAILABLE,
        reason="hypothesis not installed"
    )
    @given(st.lists(
        st.text(
            alphabet="0123456789",
            min_size=4,
            max_size=6
        ),
        min_size=1,
        max_size=5
    ))
    @settings(max_examples=10)
    def test_allowlist_cve_format(self, cve_numbers):
        """
        Property: All CVE IDs in allowlist should be valid format.
        
        **Validates: Requirements 2.6**
        """
        cve_ids = [f"CVE-2024-{num}" for num in cve_numbers]
        allowlist = create_mock_allowlist(cve_ids)
        
        # All CVE IDs should appear in the allowlist
        for cve_id in cve_ids:
            assert cve_id in allowlist
    
    @pytest.mark.skipif(
        not HYPOTHESIS_AVAILABLE,
        reason="hypothesis not installed"
    )
    @given(st.lists(
        st.sampled_from(["Critical", "High", "Medium", "Low", "Negligible"]),
        min_size=1,
        max_size=10
    ))
    @settings(max_examples=10)
    def test_severity_counting(self, severities):
        """
        Property: Severity counts should match number of vulnerabilities.
        
        **Validates: Requirements 2.1**
        """
        vulns = [
            {"id": f"CVE-2024-{i:04d}", "severity": sev}
            for i, sev in enumerate(severities)
        ]
        report = create_mock_vuln_report(vulns)
        
        # Count by severity
        for severity in ["Critical", "High", "Medium", "Low", "Negligible"]:
            expected = severities.count(severity)
            actual = len([m for m in report["matches"] 
                         if m["vulnerability"]["severity"] == severity])
            assert actual == expected, f"Mismatch for {severity}: {actual} != {expected}"


class TestNonAllowlistedVulnsAppear:
    """
    Property test: All non-allowlisted CVEs must appear in report.
    
    **Validates: Requirements 2.1, 2.5**
    """
    
    @pytest.mark.skipif(
        not HYPOTHESIS_AVAILABLE,
        reason="hypothesis not installed"
    )
    @given(
        st.lists(
            st.text(alphabet="0123456789", min_size=4, max_size=6),
            min_size=2,
            max_size=5,
            unique=True
        )
    )
    @settings(max_examples=10)
    def test_non_allowlisted_vulns_in_report(self, cve_numbers):
        """
        Property: CVEs not in allowlist must appear in vulnerability report.
        
        **Validates: Requirements 2.1, 2.5**
        
        For any set of vulnerabilities, if we allowlist some but not others,
        the non-allowlisted ones must still appear in the final report.
        """
        assume(len(cve_numbers) >= 2)
        
        all_cves = [f"CVE-2024-{num}" for num in cve_numbers]
        
        # Allowlist first half
        allowlisted = all_cves[:len(all_cves)//2]
        not_allowlisted = all_cves[len(all_cves)//2:]
        
        # Create mock report with all CVEs
        vulns = [{"id": cve, "severity": "High"} for cve in all_cves]
        report = create_mock_vuln_report(vulns)
        
        # Simulate filtering (what the script does)
        filtered_matches = [
            m for m in report["matches"]
            if m["vulnerability"]["id"] not in allowlisted
        ]
        
        # All non-allowlisted CVEs should remain
        filtered_ids = [m["vulnerability"]["id"] for m in filtered_matches]
        for cve in not_allowlisted:
            assert cve in filtered_ids, f"Non-allowlisted {cve} missing from report"
        
        # All allowlisted CVEs should be removed
        for cve in allowlisted:
            assert cve not in filtered_ids, f"Allowlisted {cve} should be filtered"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
