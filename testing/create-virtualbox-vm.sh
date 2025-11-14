#!/bin/bash
# Create VirtualBox VM for testing NubiferOS
# This script creates a VM and attaches the ISO

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# VM Configuration
VM_NAME="NubiferOS-Test"
VM_OSTYPE="Debian_64"
VM_MEMORY=4096  # 4GB RAM
VM_VRAM=128     # 128MB Video RAM
VM_CPUS=2
VM_DISK_SIZE=30720  # 30GB

# Paths
ISO_PATH="${PROJECT_ROOT}/output/nubiferos-1.0-amd64.iso"
VM_FOLDER="${HOME}/VirtualBox VMs/${VM_NAME}"

echo "=========================================="
echo "NubiferOS VirtualBox VM Creator"
echo "=========================================="
echo ""

# Check if VBoxManage is available
if ! command -v VBoxManage &> /dev/null; then
    echo "❌ VirtualBox not found. Please install VirtualBox first."
    echo "   Download from: https://www.virtualbox.org/wiki/Downloads"
    exit 1
fi

# Check if ISO exists
if [ ! -f "${ISO_PATH}" ]; then
    echo "❌ ISO not found: ${ISO_PATH}"
    echo "   Please build the ISO first with: sudo ./build-nubiferos.sh"
    exit 1
fi

echo "✅ Found ISO: ${ISO_PATH}"
ISO_SIZE=$(du -h "${ISO_PATH}" | cut -f1)
echo "   Size: ${ISO_SIZE}"
echo ""

# Check if VM already exists
if VBoxManage list vms | grep -q "\"${VM_NAME}\""; then
    echo "⚠️  VM '${VM_NAME}' already exists"
    read -p "Delete and recreate? [y/N] " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Deleting existing VM..."
        VBoxManage unregistervm "${VM_NAME}" --delete 2>/dev/null || true
    else
        echo "Cancelled"
        exit 0
    fi
fi

echo "Creating VM: ${VM_NAME}"
echo "  OS Type: ${VM_OSTYPE}"
echo "  Memory: ${VM_MEMORY}MB"
echo "  CPUs: ${VM_CPUS}"
echo "  Disk: ${VM_DISK_SIZE}MB (${VM_DISK_SIZE}/1024 GB)"
echo ""

# Create VM
VBoxManage createvm --name "${VM_NAME}" --ostype "${VM_OSTYPE}" --register

# Configure VM
VBoxManage modifyvm "${VM_NAME}" \
    --memory ${VM_MEMORY} \
    --vram ${VM_VRAM} \
    --cpus ${VM_CPUS} \
    --boot1 dvd \
    --boot2 disk \
    --boot3 none \
    --boot4 none \
    --audio-driver pulse \
    --audio-enabled on \
    --clipboard-mode bidirectional \
    --draganddrop bidirectional \
    --graphicscontroller vmsvga \
    --accelerate3d on \
    --nic1 nat \
    --natpf1 "ssh,tcp,,2222,,22"

# Create storage controller
VBoxManage storagectl "${VM_NAME}" \
    --name "SATA Controller" \
    --add sata \
    --controller IntelAhci \
    --portcount 2 \
    --bootable on

# Create virtual hard disk
DISK_PATH="${VM_FOLDER}/${VM_NAME}.vdi"
VBoxManage createhd \
    --filename "${DISK_PATH}" \
    --size ${VM_DISK_SIZE} \
    --format VDI

# Attach hard disk
VBoxManage storageattach "${VM_NAME}" \
    --storagectl "SATA Controller" \
    --port 0 \
    --device 0 \
    --type hdd \
    --medium "${DISK_PATH}"

# Attach ISO
VBoxManage storageattach "${VM_NAME}" \
    --storagectl "SATA Controller" \
    --port 1 \
    --device 0 \
    --type dvddrive \
    --medium "${ISO_PATH}"

# Enable EFI (optional, for UEFI boot testing)
# VBoxManage modifyvm "${VM_NAME}" --firmware efi

echo ""
echo "=========================================="
echo "✅ VM Created Successfully!"
echo "=========================================="
echo ""
echo "VM Name: ${VM_NAME}"
echo "Location: ${VM_FOLDER}"
echo ""
echo "To start the VM:"
echo "  VBoxManage startvm \"${VM_NAME}\" --type gui"
echo ""
echo "Or open VirtualBox GUI and start '${VM_NAME}'"
echo ""
echo "SSH Access (after installation):"
echo "  ssh -p 2222 user@localhost"
echo ""
echo "To remove the VM later:"
echo "  VBoxManage unregistervm \"${VM_NAME}\" --delete"
echo ""
