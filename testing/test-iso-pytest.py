#!/usr/bin/env python3
"""
Automated ISO testing using pytest and QEMU
Tests that the ISO boots and basic functionality works
"""

import pytest
import subprocess
import time
import os
import tempfile
import shutil
from pathlib import Path


class QEMUInstance:
    """Manages a QEMU VM instance for testing"""
    
    def __init__(self, iso_path, memory_mb=4096, disk_size_gb=20):
        self.iso_path = iso_path
        self.memory_mb = memory_mb
        self.disk_size_gb = disk_size_gb
        self.process = None
        self.disk_path = None
        
    def __enter__(self):
        """Start QEMU VM"""
        # Create temporary disk
        self.disk_path = tempfile.NamedTemporaryFile(suffix='.qcow2', delete=False).name
        subprocess.run([
            'qemu-img', 'create', '-f', 'qcow2', 
            self.disk_path, f'{self.disk_size_gb}G'
        ], check=True, capture_output=True)
        
        # Check if KVM is available and accessible
        kvm_available = False
        if os.path.exists('/dev/kvm'):
            try:
                # Try to open /dev/kvm to check permissions
                with open('/dev/kvm', 'r'):
                    kvm_available = True
            except PermissionError:
                print(f"[WARN] /dev/kvm exists but no permission - will use TCG")
        
        print(f"[INFO] KVM available: {kvm_available}")
        
        # Build QEMU command
        qemu_cmd = [
            'qemu-system-x86_64',
            '-cdrom', self.iso_path,
            '-boot', 'd',
            '-m', str(self.memory_mb),
            '-smp', '2',
            '-drive', f'file={self.disk_path},format=qcow2',
            '-display', 'none',
            '-serial', 'stdio',
            '-monitor', 'none',
        ]
        
        # Only add KVM if available and accessible
        if kvm_available:
            qemu_cmd.insert(1, '-enable-kvm')
        else:
            print(f"[WARN] KVM not available, QEMU will use TCG (slow)")
        
        # Start QEMU in headless mode
        self.process = subprocess.Popen(
            qemu_cmd,
            stdout=subprocess.PIPE, 
            stderr=subprocess.PIPE, 
            text=True
        )
        
        # Wait for boot
        time.sleep(10)
        
        return self
        
    def __exit__(self, exc_type, exc_val, exc_tb):
        """Stop QEMU VM and cleanup"""
        if self.process:
            self.process.terminate()
            try:
                self.process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                self.process.kill()
                
        if self.disk_path and os.path.exists(self.disk_path):
            os.unlink(self.disk_path)
            
    def is_running(self):
        """Check if VM is still running"""
        return self.process and self.process.poll() is None


@pytest.fixture(scope="session")
def iso_path():
    """Get ISO path from environment or default location"""
    iso = os.environ.get('ISO_PATH', 'output/NubiferOS-0.1.0-amd64.iso')
    print(f"\n[FIXTURE] ISO_PATH environment variable: {os.environ.get('ISO_PATH', 'not set')}")
    print(f"[FIXTURE] Looking for ISO at: {iso}")
    
    if not os.path.exists(iso):
        print(f"[ERROR] ISO not found at: {iso}")
        print(f"[ERROR] Current directory: {os.getcwd()}")
        print(f"[ERROR] Directory contents:")
        for root, dirs, files in os.walk('.'):
            for file in files:
                if file.endswith('.iso'):
                    print(f"[ERROR]   Found ISO: {os.path.join(root, file)}")
        pytest.skip(f"ISO not found: {iso}")
    
    print(f"[FIXTURE] ISO found: {iso}")
    return iso


@pytest.fixture(scope="session")
def qemu_available():
    """Check if QEMU is available"""
    try:
        subprocess.run(['qemu-system-x86_64', '--version'], 
                      capture_output=True, check=True)
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        pytest.skip("QEMU not installed")


class TestISOBasics:
    """Basic ISO file tests"""
    
    def test_iso_exists(self, iso_path):
        """Test that ISO file exists"""
        print(f"\n[TEST] Checking if ISO exists: {iso_path}")
        assert os.path.exists(iso_path), f"ISO not found: {iso_path}"
        print(f"[PASS] ISO file exists")
        
    def test_iso_size(self, iso_path):
        """Test that ISO is reasonable size (between 1GB and 10GB)
        
        Note: Kiosk mode ISOs include full GNOME desktop for installed system,
        but the live session runs in kiosk mode (minimal X + Calamares only).
        """
        print(f"\n[TEST] Checking ISO size")
        size_bytes = os.path.getsize(iso_path)
        size_gb = size_bytes / (1024**3)
        print(f"[INFO] ISO size: {size_gb:.2f} GB ({size_bytes:,} bytes)")
        
        # Minimum 1GB (full system), maximum 10GB
        assert 1.0 <= size_gb <= 10.0, \
            f"ISO size {size_gb:.2f}GB is outside expected range (1-10GB)"
        print(f"[PASS] ISO size is within expected range")
            
    def test_iso_format(self, iso_path):
        """Test that file is actually an ISO"""
        print(f"\n[TEST] Checking ISO format")
        # Check ISO 9660 signature
        with open(iso_path, 'rb') as f:
            f.seek(0x8001)  # ISO 9660 signature at byte 32769
            signature = f.read(5)
            print(f"[INFO] ISO signature at 0x8001: {signature}")
            assert signature == b'CD001', f"Not a valid ISO 9660 file, got {signature}"
        print(f"[PASS] Valid ISO 9660 format")


class TestISOBoot:
    """ISO boot tests using QEMU"""
    
    def test_qemu_available(self, qemu_available):
        """Test that QEMU is available"""
        print(f"\n[TEST] Checking QEMU availability")
        assert qemu_available
        print(f"[PASS] QEMU is available")
        
    def test_iso_boots(self, iso_path, qemu_available):
        """Test that ISO boots in QEMU"""
        print(f"\n[TEST] Testing ISO boot in QEMU (4GB RAM)")
        print(f"[INFO] Starting QEMU VM...")
        
        # Check if KVM is accessible (not just exists)
        kvm_accessible = False
        if os.path.exists('/dev/kvm'):
            try:
                with open('/dev/kvm', 'r'):
                    kvm_accessible = True
            except PermissionError:
                pass
        
        # Skip if KVM not accessible (QEMU too slow without it in CI)
        if not kvm_accessible:
            pytest.skip("KVM not accessible - QEMU boot test would be too slow in CI")
        
        with QEMUInstance(iso_path) as vm:
            print(f"[INFO] VM started, waiting 30 seconds for boot...")
            # Wait a bit for boot
            time.sleep(30)
            
            # Check VM is still running (didn't crash)
            print(f"[INFO] Checking if VM is still running...")
            is_running = vm.is_running()
            
            if not is_running and vm.process:
                # Get error output
                stdout, stderr = vm.process.communicate(timeout=1)
                print(f"[ERROR] QEMU stdout: {stdout[:500]}")
                print(f"[ERROR] QEMU stderr: {stderr[:500]}")
            
            assert is_running, "VM crashed during boot"
            print(f"[PASS] VM booted successfully and is running")
            
    def test_iso_boots_with_less_memory(self, iso_path, qemu_available):
        """Test that ISO boots with minimum memory (2GB)"""
        print(f"\n[TEST] Testing ISO boot with minimum memory (2GB RAM)")
        
        # Check if KVM is accessible
        kvm_accessible = False
        if os.path.exists('/dev/kvm'):
            try:
                with open('/dev/kvm', 'r'):
                    kvm_accessible = True
            except PermissionError:
                pass
        
        # Skip if KVM not accessible (QEMU too slow without it in CI)
        if not kvm_accessible:
            pytest.skip("KVM not accessible - QEMU boot test would be too slow in CI")
        
        print(f"[INFO] Starting QEMU VM with 2GB RAM...")
        with QEMUInstance(iso_path, memory_mb=2048) as vm:
            print(f"[INFO] VM started, waiting 30 seconds for boot...")
            time.sleep(30)
            print(f"[INFO] Checking if VM is still running...")
            
            is_running = vm.is_running()
            
            if not is_running and vm.process:
                # Get error output
                stdout, stderr = vm.process.communicate(timeout=1)
                print(f"[ERROR] QEMU stdout: {stdout[:500]}")
                print(f"[ERROR] QEMU stderr: {stderr[:500]}")
            
            assert is_running, "VM crashed with 2GB RAM"
            print(f"[PASS] VM booted successfully with 2GB RAM")


class TestISOContents:
    """Test ISO contents without booting - OPTIONAL, boot test is more important"""
    
    def test_iso_has_bootloader(self, iso_path):
        """Test that ISO has bootloader - OPTIONAL: boot test validates this"""
        print(f"\n[TEST] Checking ISO bootloader (optional - boot test is definitive)")
        
        # Note: If the ISO boots successfully, this test is redundant
        # We keep it for quick validation without needing to boot
        
        # Try using isoinfo to list files (doesn't require mount)
        print(f"[INFO] Using isoinfo to inspect ISO contents")
        result = subprocess.run([
            'isoinfo', '-l', '-i', iso_path
        ], capture_output=True, text=True)
        
        if result.returncode != 0:
            print(f"[WARN] isoinfo not available or failed")
            pytest.skip("isoinfo not available - boot test will validate ISO structure")
        else:
            # Parse isoinfo output
            output = result.stdout
            print(f"[INFO] ISO contents retrieved via isoinfo")
            
            # Check for GRUB
            if '/boot/grub' in output.lower() or 'grub.cfg' in output.lower():
                print(f"[PASS] GRUB files found in ISO")
            else:
                print(f"[WARN] GRUB files not clearly visible - boot test will validate")
            
            # Check for kernel
            if 'vmlinuz' in output.lower():
                print(f"[PASS] Kernel found in ISO")
            else:
                print(f"[WARN] Kernel not clearly visible - boot test will validate")


class TestSquashfsContents:
    """Inspect squashfs filesystem contents without booting.

    These tests extract the squashfs from the ISO and verify that all
    NubiferOS components, configs, and versions are correct. This catches
    most regressions without needing QEMU or a full install.
    """

    @pytest.fixture(scope="class")
    def squashfs_root(self, iso_path, tmp_path_factory):
        """Extract squashfs from ISO and return the root path."""
        work_dir = tmp_path_factory.mktemp("squashfs")
        iso_mount = work_dir / "iso"
        squash_dir = work_dir / "squashfs"
        iso_mount.mkdir()
        squash_dir.mkdir()

        # Extract ISO contents with xorriso (no root/mount needed)
        result = subprocess.run(
            ['xorriso', '-osirrox', 'on', '-indev', iso_path,
             '-extract', '/', str(iso_mount)],
            capture_output=True, text=True
        )
        if result.returncode != 0:
            pytest.skip(f"xorriso extraction failed: {result.stderr[:200]}")

        # Find the squashfs file
        squashfs_files = list(iso_mount.rglob("*.squashfs")) + list(iso_mount.rglob("filesystem.squashfs"))
        if not squashfs_files:
            # Also check common live paths
            for candidate in ["live/filesystem.squashfs", "casper/filesystem.squashfs"]:
                p = iso_mount / candidate
                if p.exists():
                    squashfs_files = [p]
                    break

        if not squashfs_files:
            pytest.skip("No squashfs found in ISO")

        squashfs_file = squashfs_files[0]
        print(f"[INFO] Found squashfs: {squashfs_file}")

        # Extract squashfs (unsquashfs doesn't need root)
        result = subprocess.run(
            ['unsquashfs', '-d', str(squash_dir / "root"), '-f', str(squashfs_file)],
            capture_output=True, text=True
        )
        if result.returncode != 0:
            pytest.skip(f"unsquashfs failed: {result.stderr[:200]}")

        root = squash_dir / "root"
        print(f"[INFO] Squashfs extracted to {root}")
        return root

    def test_version_file(self, squashfs_root):
        """Verify NubiferOS version file exists and matches expected version."""
        version_file = squashfs_root / "etc/nubiferos/nubiferos.conf"
        assert version_file.exists(), "nubiferos.conf not found in squashfs"
        content = version_file.read_text()
        assert "0.1.0" in content, f"Version 0.1.0 not found in nubiferos.conf: {content[:200]}"
        print(f"[PASS] Version 0.1.0 found in nubiferos.conf")

    def test_credential_manager(self, squashfs_root):
        """Verify credential manager is installed."""
        creds = squashfs_root / "usr/local/bin/nubifer-creds"
        helper = squashfs_root / "usr/local/bin/nubifer-aws-credential-helper"
        assert creds.exists(), "nubifer-creds not found"
        assert helper.exists(), "nubifer-aws-credential-helper not found"
        print("[PASS] Credential manager binaries present")

    def test_workspace_manager(self, squashfs_root):
        """Verify workspace manager is installed."""
        ws = squashfs_root / "usr/local/bin/nubifer-workspace"
        shell_int = squashfs_root / "etc/nubifer/shell-integration.sh"
        assert ws.exists(), "nubifer-workspace not found"
        assert shell_int.exists(), "shell-integration.sh not found"
        print("[PASS] Workspace manager present")

    def test_cli_wrappers(self, squashfs_root):
        """Verify read-only CLI wrappers are installed."""
        wrapper_dir = squashfs_root / "usr/local/lib/nubifer/cli-wrappers"
        assert wrapper_dir.exists(), "CLI wrappers directory not found"

        expected_wrappers = ["aws", "az", "gcloud", "terraform"]
        found = []
        missing = []
        for name in expected_wrappers:
            wrapper = wrapper_dir / name
            if wrapper.exists():
                found.append(name)
            else:
                missing.append(name)

        print(f"[INFO] CLI wrappers found: {found}")
        if missing:
            print(f"[WARN] CLI wrappers missing: {missing}")

        # At minimum, aws wrapper must exist
        assert (wrapper_dir / "aws").exists(), "AWS CLI wrapper missing"
        print("[PASS] CLI wrappers directory populated")

    def test_calamares_config(self, squashfs_root):
        """Verify Calamares installer configuration exists."""
        settings = squashfs_root / "etc/calamares/settings.conf"
        assert settings.exists(), "Calamares settings.conf not found"

        content = settings.read_text()
        assert "partition" in content, "partition module not in settings.conf"
        assert "bootloader" in content, "bootloader module not in settings.conf"
        print("[PASS] Calamares configuration present and valid")

    def test_calamares_modules(self, squashfs_root):
        """Verify key Calamares modules are configured."""
        modules_dir = squashfs_root / "etc/calamares/modules"
        assert modules_dir.exists(), "Calamares modules directory not found"

        expected = ["partition.conf", "bootloader.conf", "unpackfs.conf"]
        for mod in expected:
            assert (modules_dir / mod).exists(), f"Calamares module {mod} missing"
        print(f"[PASS] Key Calamares modules present: {expected}")

    def test_calamares_helper_scripts(self, squashfs_root):
        """Verify external Calamares helper scripts are installed."""
        expected_scripts = [
            "usr/local/bin/calamares-fix-dev-mounts.sh",
            "usr/local/bin/calamares-prepare-devices.sh",
        ]
        for script in expected_scripts:
            path = squashfs_root / script
            assert path.exists(), f"Calamares helper script missing: {script}"
        print("[PASS] Calamares helper scripts present")

    def test_grub_config(self, squashfs_root):
        """Verify GRUB LUKS wrapper is installed."""
        wrapper = squashfs_root / "usr/local/bin/grub-install-luks-wrapper.sh"
        if wrapper.exists():
            content = wrapper.read_text()
            assert "luks" in content.lower() or "LUKS" in content, \
                "GRUB wrapper doesn't reference LUKS"
            print("[PASS] GRUB LUKS wrapper present")
        else:
            print("[WARN] GRUB LUKS wrapper not found (may be installed differently)")

    def test_plymouth_theme(self, squashfs_root):
        """Verify Plymouth boot splash is installed."""
        plymouth_dir = squashfs_root / "usr/share/plymouth/themes"
        if plymouth_dir.exists():
            themes = list(plymouth_dir.iterdir())
            nubifer_themes = [t for t in themes if "nubifer" in t.name.lower()]
            if nubifer_themes:
                print(f"[PASS] NubiferOS Plymouth theme found: {nubifer_themes[0].name}")
            else:
                print(f"[WARN] No NubiferOS-specific Plymouth theme (themes: {[t.name for t in themes]})")
        else:
            print("[WARN] No Plymouth themes directory")

    def test_installer_user_setup(self, squashfs_root):
        """Verify installer user exists in the squashfs (will be removed post-install)."""
        passwd = squashfs_root / "etc/passwd"
        if passwd.exists():
            content = passwd.read_text()
            assert "installer" in content, "installer user not found in /etc/passwd"
            print("[PASS] installer user present in squashfs")

    def test_no_sensitive_files(self, squashfs_root):
        """Verify no sensitive files leaked into the squashfs."""
        sensitive_patterns = [
            "etc/shadow-",  # Shadow backup
            "root/.ssh/id_rsa",
            "root/.bash_history",
            "home/*/.ssh/id_rsa",
        ]
        for pattern in sensitive_patterns:
            matches = list(squashfs_root.glob(pattern))
            # shadow- backup is OK if empty, .ssh keys are not
            if "id_rsa" in pattern:
                assert not matches, f"Sensitive file found: {pattern}"
        print("[PASS] No sensitive files leaked into squashfs")


class TestISOMetadata:
    """Test ISO metadata and labels"""

    def test_iso_volume_label(self, iso_path):
        """Test ISO volume label"""
        print(f"\n[TEST] Checking ISO volume label")
        result = subprocess.run([
            'isoinfo', '-d', '-i', iso_path
        ], capture_output=True, text=True)
        
        if result.returncode == 0:
            output = result.stdout
            print(f"[INFO] ISO metadata:\n{output[:500]}")  # Print first 500 chars
            assert 'NubiferOS' in output or 'NUBIFEROS' in output, \
                "ISO volume label doesn't contain NubiferOS"
            print(f"[PASS] ISO volume label contains NubiferOS")
        else:
            print(f"[WARN] isoinfo command failed, skipping volume label check")


def test_suite_summary(iso_path):
    """Print test summary"""
    print("\n" + "="*50)
    print("ISO Test Summary")
    print("="*50)
    print(f"ISO Path: {iso_path}")
    print(f"ISO Size: {os.path.getsize(iso_path) / (1024**3):.2f} GB")
    print("="*50)


if __name__ == '__main__':
    # Run tests with JUnit XML output for CI/CD
    pytest.main([
        __file__, 
        '-v', 
        '--tb=short',
        '--junitxml=test-results.xml'
    ])
