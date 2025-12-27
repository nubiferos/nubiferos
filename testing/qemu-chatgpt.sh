#!/bin/bash
# Launch QEMU with SPICE support (optionally UEFI/OVMF)

set -euo pipefail

# ===== Settings =====
USE_UEFI="${USE_UEFI:-1}"   # default: 1 (UEFI). Set USE_UEFI=0 to force BIOS.
RAM_MB="${RAM_MB:-4096}"
CPUS="${CPUS:-2}"
SPICE_PORT="${SPICE_PORT:-5930}"

# Find the ISO file
ISO_FILE=""
if [ -n "${1:-}" ]; then
  ISO_FILE="$1"
else
  ISO_FILE=$(ls -t output/nubiferos-*.iso 2>/dev/null | head -1 || true)
fi

if [ -z "$ISO_FILE" ] || [ ! -f "$ISO_FILE" ]; then
  echo "Error: ISO file not found"
  echo ""
  echo "Usage: $0 [path/to/iso]"
  echo "Or place ISO in output/ directory"
  exit 1
fi

echo "=========================================="
echo "QEMU with SPICE Support"
echo "=========================================="
echo "ISO: $ISO_FILE"
echo "UEFI: $USE_UEFI"
echo "=========================================="
echo ""

# Check if KVM is available
KVM_OPTS=""
if [ -e /dev/kvm ] && [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
  echo "✓ KVM acceleration available"
  KVM_OPTS="-enable-kvm -cpu host"
else
  echo "⚠ KVM not available - using software emulation (slower)"
fi

# Create virtual disk if it doesn't exist
mkdir -p testing
DISK_FILE="testing/nubiferos-test-disk.qcow2"
if [ ! -f "$DISK_FILE" ]; then
  echo "Creating 20GB virtual disk for testing..."
  qemu-img create -f qcow2 "$DISK_FILE" 20G
  echo "✓ Virtual disk created: $DISK_FILE"
fi

# ===== UEFI (OVMF) setup =====
UEFI_OPTS=""
if [ "$USE_UEFI" = "1" ]; then
  # Common OVMF locations on Debian/Ubuntu
  OVMF_CODE_CANDIDATES=(
    /usr/share/OVMF/OVMF_CODE.fd
    /usr/share/OVMF/OVMF_CODE_4M.fd
    /usr/share/edk2/ovmf/OVMF_CODE.fd
    /usr/share/edk2/ovmf/OVMF_CODE_4M.fd
  )
  OVMF_VARS_CANDIDATES=(
    /usr/share/OVMF/OVMF_VARS.fd
    /usr/share/OVMF/OVMF_VARS_4M.fd
    /usr/share/edk2/ovmf/OVMF_VARS.fd
    /usr/share/edk2/ovmf/OVMF_VARS_4M.fd
  )

  OVMF_CODE=""
  OVMF_VARS_TEMPLATE=""
  for f in "${OVMF_CODE_CANDIDATES[@]}"; do
    if [ -f "$f" ]; then OVMF_CODE="$f"; break; fi
  done
  for f in "${OVMF_VARS_CANDIDATES[@]}"; do
    if [ -f "$f" ]; then OVMF_VARS_TEMPLATE="$f"; break; fi
  done

  if [ -z "$OVMF_CODE" ] || [ -z "$OVMF_VARS_TEMPLATE" ]; then
    echo "⚠ USE_UEFI=1 but OVMF firmware not found."
    echo "  Install it with: sudo apt install ovmf"
    echo "  Falling back to BIOS."
    USE_UEFI=0
  else
    # Keep per-disk NVRAM vars (persistent boot entries)
    OVMF_VARS="testing/OVMF_VARS.fd"
    if [ ! -f "$OVMF_VARS" ]; then
      cp "$OVMF_VARS_TEMPLATE" "$OVMF_VARS"
    fi

    echo "✓ Using OVMF:"
    echo "  CODE: $OVMF_CODE"
    echo "  VARS: $OVMF_VARS"
    echo ""

    # q35 + pflash is a solid default for UEFI
    UEFI_OPTS="-machine q35 \
      -drive if=pflash,format=raw,readonly=on,file=$OVMF_CODE \
      -drive if=pflash,format=raw,file=$OVMF_VARS"
  fi
fi

echo "Starting QEMU..."
echo "Connect with:"
echo "  spicy --uri=spice://localhost:${SPICE_PORT}"
echo ""

# Launch QEMU with SPICE
qemu-system-x86_64 \
  $KVM_OPTS \
  $UEFI_OPTS \
  -m "$RAM_MB" \
  -smp "$CPUS" \
  -boot d \
  -drive file="$ISO_FILE",media=cdrom,readonly=on,format=raw,if=ide \
  -drive file="$DISK_FILE",format=qcow2,if=virtio \
  -vga qxl \
  -spice port="$SPICE_PORT",addr=127.0.0.1,disable-ticketing=on \
  -device virtio-serial-pci \
  -device virtserialport,chardev=spicechannel0,name=com.redhat.spice.0 \
  -chardev spicevmc,id=spicechannel0,name=vdagent \
  -usb \
  -device usb-tablet \
  -device usb-kbd

echo ""
echo "QEMU exited"
