#!/bin/bash
# Detect TPM 2.0 and adjust Calamares partition config accordingly
#
# Runs as ExecStartPre before Calamares launches.
# If TPM 2.0 is present and functional:
#   - Switch partition.conf from luks1 to luks2
#   - Add partitionLayout with separate unencrypted /boot
#   - Create marker file for downstream scripts
# If no TPM: exit 0, no changes.

set -e

PARTITION_CONF="/etc/calamares/modules/partition.conf"
MARKER="/tmp/nubiferos-tpm-detected"

echo "=========================================="
echo "NubiferOS TPM 2.0 Detection"
echo "=========================================="

# Check 1: /dev/tpmrm0 device node
if [ ! -c /dev/tpmrm0 ]; then
    echo "No /dev/tpmrm0 device found — no TPM present"
    echo "Keeping LUKS1 configuration (current behavior)"
    exit 0
fi
echo "✓ /dev/tpmrm0 device found"

# Check 2: TPM version is 2
TPM_VERSION=""
if [ -f /sys/class/tpm/tpm0/tpm_version_major ]; then
    TPM_VERSION=$(cat /sys/class/tpm/tpm0/tpm_version_major)
fi
if [ "$TPM_VERSION" != "2" ]; then
    echo "TPM version is '${TPM_VERSION}', not 2 — skipping"
    echo "Keeping LUKS1 configuration (current behavior)"
    exit 0
fi
echo "✓ TPM version 2 confirmed"

# Check 3: Functional verification via tpm2_pcrread
if ! tpm2_pcrread sha256:7 >/dev/null 2>&1; then
    echo "tpm2_pcrread failed — TPM not functional"
    echo "Keeping LUKS1 configuration (current behavior)"
    exit 0
fi
echo "✓ TPM 2.0 is functional (PCR 7 readable)"

echo ""
echo "TPM 2.0 detected — switching to LUKS2 + unencrypted /boot"
echo ""

# Modify partition.conf: luks1 → luks2
if [ -f "$PARTITION_CONF" ]; then
    sed -i 's/^luksGeneration: luks1$/luksGeneration: luks2/' "$PARTITION_CONF"
    echo "✓ Updated luksGeneration to luks2"

    # Add partitionLayout for separate unencrypted /boot + encrypted root
    # Only add if not already present
    if ! grep -q "partitionLayout:" "$PARTITION_CONF"; then
        cat >> "$PARTITION_CONF" << 'LAYOUT'

# TPM layout: unencrypted /boot (GRUB can't decrypt LUKS2+Argon2id)
# TPM PCR7 provides Evil Maid protection instead of encrypted /boot
partitionLayout:
    - name: "boot"
      filesystem: "ext4"
      mountPoint: "/boot"
      size: 1024M
      minSize: 512M
    - name: "root"
      filesystem: "ext4"
      mountPoint: "/"
      size: 100%
      minSize: 8192M
      encrypted: true
LAYOUT
        echo "✓ Added partitionLayout with separate /boot"
    else
        echo "partitionLayout already present, skipping"
    fi
else
    echo "WARNING: $PARTITION_CONF not found — cannot modify"
    exit 0
fi

# Create marker file for downstream scripts (bind-tpm, prepare-bootloader)
cat > "$MARKER" << EOF
# NubiferOS TPM 2.0 detected at $(date -u +"%Y-%m-%dT%H:%M:%SZ")
TPM_VERSION=2
LUKS_GENERATION=luks2
BOOT_ENCRYPTED=false
EOF

echo "✓ Created marker: $MARKER"
echo ""
echo "=========================================="
echo "TPM detection complete — LUKS2 mode active"
echo "=========================================="

exit 0
