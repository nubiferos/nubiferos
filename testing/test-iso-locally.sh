#!/bin/bash
# Test NubiferOS ISO locally using QEMU/VirtualBox
# This is MUCH faster than AWS conversion and tests the actual ISO

set -e

ISO_FILE="${1:-output/NubiferOS-1.0-amd64.iso}"
TEST_MODE="${2:-qemu}"  # qemu, virtualbox, or both

echo "=========================================="
echo "NubiferOS ISO Local Testing"
echo "=========================================="
echo ""
echo "ISO File: $ISO_FILE"
echo "Test Mode: $TEST_MODE"
echo ""

# Check if ISO exists
if [ ! -f "$ISO_FILE" ]; then
    echo "❌ ISO file not found: $ISO_FILE"
    echo ""
    echo "Usage: $0 [iso-file] [test-mode]"
    echo "  iso-file: Path to ISO (default: output/NubiferOS-1.0-amd64.iso)"
    echo "  test-mode: qemu, virtualbox, or both (default: qemu)"
    exit 1
fi

# Get ISO size
ISO_SIZE=$(du -h "$ISO_FILE" | cut -f1)
echo "ISO Size: $ISO_SIZE"
echo ""

# Function to test with QEMU
test_with_qemu() {
    echo "=========================================="
    echo "Testing with QEMU"
    echo "=========================================="
    echo ""
    
    # Check if QEMU is installed
    if ! command -v qemu-system-x86_64 &> /dev/null; then
        echo "❌ QEMU not installed"
        echo ""
        echo "Install with:"
        echo "  Ubuntu/Debian: sudo apt-get install qemu-system-x86"
        echo "  macOS: brew install qemu"
        echo "  Fedora: sudo dnf install qemu-system-x86"
        return 1
    fi
    
    echo "✅ QEMU installed: $(qemu-system-x86_64 --version | head -1)"
    echo ""
    
    echo "Starting QEMU VM..."
    echo "  Memory: 4GB"
    echo "  Disk: 20GB (temporary)"
    echo "  Display: GTK window"
    echo ""
    echo "The VM will boot from the ISO."
    echo "Test the installation process manually."
    echo "Close the window when done."
    echo ""
    
    # Create temporary disk
    TEMP_DISK=$(mktemp -u).qcow2
    qemu-img create -f qcow2 "$TEMP_DISK" 20G
    
    echo "Press Enter to start VM..."
    read
    
    # Start QEMU
    qemu-system-x86_64 \
        -cdrom "$ISO_FILE" \
        -boot d \
        -m 4096 \
        -smp 2 \
        -drive file="$TEMP_DISK",format=qcow2 \
        -enable-kvm \
        -display gtk \
        -vga virtio \
        -net nic -net user
    
    # Cleanup
    rm -f "$TEMP_DISK"
    
    echo ""
    echo "✅ QEMU test complete"
}

# Function to test with VirtualBox
test_with_virtualbox() {
    echo "=========================================="
    echo "Testing with VirtualBox"
    echo "=========================================="
    echo ""
    
    # Check if VirtualBox is installed
    if ! command -v VBoxManage &> /dev/null; then
        echo "❌ VirtualBox not installed"
        echo ""
        echo "Install from: https://www.virtualbox.org/wiki/Downloads"
        return 1
    fi
    
    echo "✅ VirtualBox installed: $(VBoxManage --version)"
    echo ""
    
    VM_NAME="NubiferOS-Test-$(date +%s)"
    
    echo "Creating VirtualBox VM: $VM_NAME"
    
    # Create VM
    VBoxManage createvm --name "$VM_NAME" --ostype Debian_64 --register
    
    # Configure VM
    VBoxManage modifyvm "$VM_NAME" \
        --memory 4096 \
        --cpus 2 \
        --vram 128 \
        --graphicscontroller vmsvga \
        --boot1 dvd \
        --boot2 disk \
        --boot3 none \
        --boot4 none \
        --audio none \
        --usb on \
        --usbehci on
    
    # Create and attach disk
    DISK_PATH="$HOME/VirtualBox VMs/$VM_NAME/$VM_NAME.vdi"
    VBoxManage createhd --filename "$DISK_PATH" --size 20480
    VBoxManage storagectl "$VM_NAME" --name "SATA" --add sata --controller IntelAhci
    VBoxManage storageattach "$VM_NAME" --storagectl "SATA" --port 0 --device 0 --type hdd --medium "$DISK_PATH"
    
    # Attach ISO
    VBoxManage storagectl "$VM_NAME" --name "IDE" --add ide
    VBoxManage storageattach "$VM_NAME" --storagectl "IDE" --port 0 --device 0 --type dvddrive --medium "$ISO_FILE"
    
    echo ""
    echo "✅ VM created: $VM_NAME"
    echo ""
    echo "Starting VM..."
    echo "Test the installation process manually."
    echo "The VM will remain for further testing."
    echo ""
    echo "To delete VM later:"
    echo "  VBoxManage unregistervm $VM_NAME --delete"
    echo ""
    
    # Start VM
    VBoxManage startvm "$VM_NAME"
    
    echo ""
    echo "✅ VirtualBox test started"
    echo "VM Name: $VM_NAME"
}

# Run tests based on mode
case $TEST_MODE in
    qemu)
        test_with_qemu
        ;;
    virtualbox)
        test_with_virtualbox
        ;;
    both)
        test_with_qemu
        echo ""
        test_with_virtualbox
        ;;
    *)
        echo "❌ Invalid test mode: $TEST_MODE"
        echo "Valid modes: qemu, virtualbox, both"
        exit 1
        ;;
esac

echo ""
echo "=========================================="
echo "Testing Complete"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Verify ISO boots correctly"
echo "2. Test installation process"
echo "3. Check installed system"
echo "4. If all looks good, proceed with AWS testing"
echo ""
