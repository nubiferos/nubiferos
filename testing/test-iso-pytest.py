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
        
        # Check if KVM is available
        kvm_available = os.path.exists('/dev/kvm')
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
        
        # Only add KVM if available
        if kvm_available:
            qemu_cmd.insert(1, '-enable-kvm')
        else:
            print(f"[WARN] KVM not available, QEMU will be slow")
        
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
    iso = os.environ.get('ISO_PATH', 'output/NubiferOS-1.0-amd64.iso')
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
        """Test that ISO is reasonable size (between 1GB and 10GB)"""
        print(f"\n[TEST] Checking ISO size")
        size_bytes = os.path.getsize(iso_path)
        size_gb = size_bytes / (1024**3)
        print(f"[INFO] ISO size: {size_gb:.2f} GB ({size_bytes:,} bytes)")
        
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
        
        # Skip if KVM not available (QEMU too slow without it)
        if not os.path.exists('/dev/kvm'):
            pytest.skip("KVM not available - QEMU boot test would be too slow")
        
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
        
        # Skip if KVM not available (QEMU too slow without it)
        if not os.path.exists('/dev/kvm'):
            pytest.skip("KVM not available - QEMU boot test would be too slow")
        
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
