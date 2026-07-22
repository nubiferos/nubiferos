#!/bin/bash
# One command to launch a NubiferOS VM from a tested ISO — resolves + caches
# the ISO, keeps a persistent disk, and boots a window on your desktop. No
# manual download / mount / power-on.
#
# Uses QEMU/KVM by default (coexists with the boot-test harness and needs no
# module juggling). VirtualBox is available via --vbox but requires the KVM
# modules unloaded first (`sudo modprobe -r kvm_intel kvm`), since VBox wants
# VT-x exclusively.
#
# Usage:
#   testing/launch-vm.sh                 # latest tested ISO from S3, GUI window
#   testing/launch-vm.sh --commit b20bf82
#   testing/launch-vm.sh /path/to.iso
#   testing/launch-vm.sh --fresh         # wipe the install disk first
#   testing/launch-vm.sh --boot-disk     # boot the INSTALLED disk (no ISO)
#   testing/launch-vm.sh --headless      # no window (serial + VNC :0)
#   testing/launch-vm.sh --tpm           # emulated TPM 2.0 (needs swtpm)
#   testing/launch-vm.sh --vbox          # use VirtualBox instead of QEMU
#
# Flags: --name N  --mem MB  --cpus N  --disk-gb N
set -euo pipefail

VM_NAME="NubiferOS-Test"
MEM=4096; CPUS=2; DISK_GB=30
BUCKET="nubiferos-iso"
CACHE="${HOME}/.cache/nubiferos-iso"
ISO_ARG=""; WANT_TPM=0; FRESH=0; HEADLESS=0; BOOT_DISK=0; COMMIT=""; USE_VBOX=0

while [ $# -gt 0 ]; do
    case "$1" in
        --tpm) WANT_TPM=1 ;;
        --fresh) FRESH=1 ;;
        --headless) HEADLESS=1 ;;
        --boot-disk) BOOT_DISK=1 ;;
        --vbox) USE_VBOX=1 ;;
        --commit) COMMIT="$2"; shift ;;
        --name) VM_NAME="$2"; shift ;;
        --mem) MEM="$2"; shift ;;
        --cpus) CPUS="$2"; shift ;;
        --disk-gb) DISK_GB="$2"; shift ;;
        -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *.iso) ISO_ARG="$1" ;;
        *) echo "unknown arg: $1" >&2; exit 2 ;;
    esac
    shift
done

mkdir -p "$CACHE"

# ---- Resolve the ISO -------------------------------------------------------
resolve_iso() {
    if [ -n "$ISO_ARG" ]; then
        ISO="$ISO_ARG"; [ -f "$ISO" ] || { echo "ERROR: ISO not found: $ISO"; exit 2; }
    elif [ "$BOOT_DISK" = 1 ]; then
        ISO=""
    else
        command -v aws >/dev/null || { echo "ERROR: aws CLI needed to fetch ISO (or pass a path)"; exit 2; }
        if [ -z "$COMMIT" ]; then
            echo "Resolving latest tested ISO from s3://$BUCKET/staging/builds.json ..."
            local meta
            meta=$(aws s3 cp "s3://$BUCKET/staging/builds.json" - 2>/dev/null \
                | python3 -c "import json,sys; b=json.load(sys.stdin)['builds'][0]; print(b['commit'], b['iso_file'], b.get('status','?'))")
            COMMIT=$(echo "$meta" | awk '{print $1}')
            ISO_FILE=$(echo "$meta" | awk '{print $2}')
            echo "  latest: $meta"
        else
            ISO_FILE=$(aws s3 ls "s3://$BUCKET/staging/builds/$COMMIT/" | grep '\.iso$' | grep -v '\.asc' | awk '{print $4}' | head -1)
            [ -n "$ISO_FILE" ] || { echo "ERROR: no ISO in staging/builds/$COMMIT/"; exit 2; }
        fi
        ISO="$CACHE/$ISO_FILE"
        if [ -f "$ISO" ]; then echo "  cached: $ISO"
        else echo "  downloading -> $ISO"; aws s3 cp "s3://$BUCKET/staging/builds/$COMMIT/$ISO_FILE" "$ISO" --no-progress; fi
    fi
}
resolve_iso

DISK_QCOW="$CACHE/${VM_NAME}.qcow2"
SERIAL="$CACHE/${VM_NAME}-serial.log"

# ---- VirtualBox backend (opt-in) ------------------------------------------
if [ "$USE_VBOX" = 1 ]; then
    command -v VBoxManage >/dev/null || { echo "ERROR: VirtualBox not installed"; exit 2; }
    if lsmod | grep -q '^kvm_intel'; then
        echo "ERROR: KVM modules are loaded — VirtualBox can't grab VT-x."
        echo "       Run: sudo modprobe -r kvm_intel kvm   (then re-run with --vbox)"
        echo "       Or just omit --vbox to use QEMU (recommended here)."
        exit 2
    fi
    VDISK="$CACHE/${VM_NAME}.vdi"
    VBoxManage controlvm "$VM_NAME" poweroff >/dev/null 2>&1 || true; sleep 1
    VBoxManage unregistervm "$VM_NAME" >/dev/null 2>&1 || true
    [ "$FRESH" = 1 ] && rm -f "$VDISK"
    VBoxManage createvm --name "$VM_NAME" --ostype Debian_64 --register >/dev/null
    VBoxManage modifyvm "$VM_NAME" --memory "$MEM" --cpus "$CPUS" --vram 128 \
        --graphicscontroller vmsvga --nic1 nat --audio-driver none >/dev/null
    [ "$WANT_TPM" = 1 ] && VBoxManage modifyvm "$VM_NAME" --tpm-type 2.0 >/dev/null 2>&1 || true
    [ -f "$VDISK" ] || VBoxManage createmedium disk --filename "$VDISK" --size $((DISK_GB*1024)) >/dev/null
    VBoxManage storagectl "$VM_NAME" --name SATA --add sata --controller IntelAhci >/dev/null
    VBoxManage storageattach "$VM_NAME" --storagectl SATA --port 0 --device 0 --type hdd --medium "$VDISK" >/dev/null
    VBoxManage storagectl "$VM_NAME" --name IDE --add ide >/dev/null
    if [ "$BOOT_DISK" = 1 ]; then VBoxManage modifyvm "$VM_NAME" --boot1 disk >/dev/null
    else VBoxManage storageattach "$VM_NAME" --storagectl IDE --port 0 --device 0 --type dvddrive --medium "$ISO" >/dev/null
         VBoxManage modifyvm "$VM_NAME" --boot1 dvd --boot2 disk >/dev/null; fi
    VBoxManage startvm "$VM_NAME" --type $([ "$HEADLESS" = 1 ] && echo headless || echo gui) >/dev/null
    echo "✓ VirtualBox VM '$VM_NAME' launched."
    exit 0
fi

# ---- QEMU backend (default) ------------------------------------------------
command -v qemu-system-x86_64 >/dev/null || { echo "ERROR: qemu-system-x86_64 not installed"; exit 2; }
[ "$FRESH" = 1 ] && rm -f "$DISK_QCOW"
[ -f "$DISK_QCOW" ] || qemu-img create -f qcow2 "$DISK_QCOW" "${DISK_GB}G" >/dev/null

ACCEL=(); [ -w /dev/kvm ] && ACCEL=(-enable-kvm -cpu host) || { echo "note: no KVM, using slow emulation"; ACCEL=(-cpu max); }

QEMU_ARGS=(
    "${ACCEL[@]}" -m "$MEM" -smp "$CPUS" -name "$VM_NAME"
    -drive file="$DISK_QCOW",format=qcow2,if=virtio
    # User-mode NAT networking — the NubiferOS install fetches packages from
    # Debian mirrors during Calamares (the ISO ships a cleaned apt cache), so
    # the VM MUST have working outbound network or the package step fails 100.
    -nic user,model=virtio-net-pci
    -serial "file:$SERIAL" -vga std
)
[ "$BOOT_DISK" = 1 ] || QEMU_ARGS+=(-cdrom "$ISO" -boot d)

# Emulated TPM 2.0 via swtpm (optional)
SWTPM_STARTED=0
if [ "$WANT_TPM" = 1 ]; then
    if command -v swtpm >/dev/null; then
        TPMDIR="$CACHE/${VM_NAME}-tpm"; mkdir -p "$TPMDIR"
        swtpm socket --tpmstate dir="$TPMDIR" --ctrl type=unixio,path="$TPMDIR/sock" --tpm2 --daemon
        QEMU_ARGS+=(-chardev "socket,id=chrtpm,path=$TPMDIR/sock" -tpmdev "emulator,id=tpm0,chardev=chrtpm" -device "tpm-tis,tpmdev=tpm0")
        SWTPM_STARTED=1; echo "  ✓ emulated TPM 2.0 attached"
    else
        echo "  ⚠ --tpm requested but swtpm not installed (sudo apt install swtpm) — continuing without"
    fi
fi

if [ "$HEADLESS" = 1 ]; then
    QEMU_ARGS+=(-display none -vnc :0)
    echo "Launching headless (VNC on :5900, serial $SERIAL)..."
else
    QEMU_ARGS+=(-display gtk)
    echo "Opening NubiferOS window on your desktop..."
fi

echo "  ISO:  ${ISO:-<none, booting installed disk>}"
echo "  Disk: $DISK_QCOW (${DISK_GB}G, persistent)"
echo "  Serial log: $SERIAL"
echo ""
# Detach so the window persists after this script returns
nohup qemu-system-x86_64 "${QEMU_ARGS[@]}" >/dev/null 2>&1 &
echo "✓ VM launched (pid $!). Close the window or: pkill -f 'qemu.*$VM_NAME'"
echo "  After install, reboot into the installed system: testing/launch-vm.sh --boot-disk"
