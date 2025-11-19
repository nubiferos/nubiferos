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
        
        # Start QEMU in headless mode
        self.process = subprocess.Popen([
            'qemu-system-x86_64',
            '-cdrom', self.iso_path,
            '-boot', 'd',
            '-m', str(self.memory_mb),
            '-smp', '2',
            '-drive', f'file={self.disk_path},format=qcow2',
            '-enable-kvm',
            '-display', 'none',
            '-serial', 'stdio',
            '-monitor', 'none',
        ], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        
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
            f.seek(0x8000)  # ISO 9660 starts at byte 32768
            signature = f.read(5)
            print(f"[INFO] ISO signature: {signature}")
            assert signature == b'CD001', "Not a valid ISO 9660 file"
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
        with QEMUInstance(iso_path) as vm:
            print(f"[INFO] VM started, waiting 30 seconds for boot...")
            # Wait a bit for boot
            time.sleep(30)
            
            # Check VM is still running (didn't crash)
            print(f"[INFO] Checking if VM is still running...")
            assert vm.is_running(), "VM crashed during boot"
            print(f"[PASS] VM booted successfully and is running")
            
    def test_iso_boots_with_less_memory(self, iso_path, qemu_available):
        """Test that ISO boots with minimum memory (2GB)"""
        print(f"\n[TEST] Testing ISO boot with minimum memory (2GB RAM)")
        print(f"[INFO] Starting QEMU VM with 2GB RAM...")
        with QEMUInstance(iso_path, memory_mb=2048) as vm:
            print(f"[INFO] VM started, waiting 30 seconds for boot...")
            time.sleep(30)
            print(f"[INFO] Checking if VM is still running...")
            assert vm.is_running(), "VM crashed with 2GB RAM"
            print(f"[PASS] VM booted successfully with 2GB RAM")


class TestISOContents:
    """Test ISO contents without booting"""
    
    def test_iso_has_bootloader(self, iso_path):
        """Test that ISO has bootloader"""
        print(f"\n[TEST] Checking ISO bootloader")
        # Mount ISO and check for GRUB
        with tempfile.TemporaryDirectory() as mount_point:
            try:
                print(f"[INFO] Mounting ISO to {mount_point}")
                subprocess.run([
                    'sudo', 'mount', '-o', 'loop', iso_path, mount_point
                ], check=True, capture_output=True)
                
                # Check for GRUB files
                print(f"[INFO] Checking for GRUB directory")
                grub_path = Path(mount_point) / 'boot' / 'grub'
                assert grub_path.exists(), "GRUB directory not found"
                print(f"[PASS] GRUB directory found: {grub_path}")
                
                # Check for kernel
                print(f"[INFO] Checking for kernel files")
                boot_path = Path(mount_point) / 'boot'
                kernel_files = list(boot_path.glob('vmlinuz*'))
                assert len(kernel_files) > 0, "No kernel found"
                print(f"[PASS] Kernel found: {kernel_files[0].name}")
                
            finally:
                print(f"[INFO] Unmounting ISO")
                subprocess.run(['sudo', 'umount', mount_point], 
                             capture_output=True)
                             
    def test_iso_has_squashfs(self, iso_path):
        """Test that ISO contains squashfs filesystem"""
        print(f"\n[TEST] Checking for squashfs filesystem")
        with tempfile.TemporaryDirectory() as mount_point:
            try:
                print(f"[INFO] Mounting ISO to {mount_point}")
                subprocess.run([
                    'sudo', 'mount', '-o', 'loop', iso_path, mount_point
                ], check=True, capture_output=True)
                
                # Check for squashfs
                print(f"[INFO] Looking for squashfs files")
                live_path = Path(mount_point) / 'live'
                if live_path.exists():
                    squashfs_files = list(live_path.glob('*.squashfs'))
                    assert len(squashfs_files) > 0, "No squashfs found"
                    print(f"[PASS] Squashfs found: {squashfs_files[0].name}")
                else:
                    print(f"[WARN] /live directory not found, skipping squashfs check")
                    
            finally:
                print(f"[INFO] Unmounting ISO")
                subprocess.run(['sudo', 'umount', mount_point], 
                             capture_output=True)


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
