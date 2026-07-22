#!/bin/bash
# Verify that security-critical files inside an ISO byte-match their source
# at the commit the ISO was built from (build fidelity), and warn if trunk
# has since moved ahead on any of them (staleness).
#
# Why: the boot test proves an ISO RUNS; it cannot prove the ISO CONTAINS
# what the source says. CI has twice shipped ISOs whose contents silently
# diverged from source — installer configs overwritten by dev scaffolding
# (dropping the TPM stack), and a read-only-bypass fix that landed after a
# nightly build. This check makes those failures loud instead of latent.
#
# Usage: verify-iso-contents.sh <iso> <built-commit> [trunk-ref]
# Needs: unsquashfs, xorriso, git (with the built commit in history —
#        checkout with fetch-depth: 0). Exit 0 pass, 1 fidelity mismatch,
#        2 setup error.

set -u

ISO="${1:?usage: verify-iso-contents.sh <iso> <built-commit> [trunk-ref]}"
COMMIT="${2:?built commit sha required}"
TRUNK_REF="${3:-origin/trunk}"

command -v unsquashfs >/dev/null || { echo "ERROR: unsquashfs missing"; exit 2; }
command -v xorriso   >/dev/null || { echo "ERROR: xorriso missing"; exit 2; }
[ -f "$ISO" ] || { echo "ERROR: ISO not found: $ISO"; exit 2; }
git cat-file -e "$COMMIT^{commit}" 2>/dev/null || {
    echo "ERROR: commit $COMMIT not in git history (use fetch-depth: 0)"; exit 2; }

# install-path-in-squashfs  <TAB>  source-path-in-repo
# Only files copied VERBATIM by the build belong here (byte-comparable).
# Transformed files (version-stamped configs) are deliberately excluded.
MAP=$(cat <<'EOF'
usr/local/lib/nubifer/cli-wrappers/aws	components/workspace-manager/cli-wrappers/aws
usr/local/lib/nubifer/cli-wrappers/az	components/workspace-manager/cli-wrappers/az
usr/local/lib/nubifer/cli-wrappers/gcloud	components/workspace-manager/cli-wrappers/gcloud
usr/local/lib/nubifer/cli-wrappers/oci	components/workspace-manager/cli-wrappers/oci
usr/local/lib/nubifer/cli-wrappers/terraform	components/workspace-manager/cli-wrappers/terraform
usr/local/bin/nubifer-workspace	components/workspace-manager/nubifer-workspace
usr/local/bin/nubifer-creds	components/credential-manager/nubifer-creds
usr/local/bin/nubifer-aws-credential-helper	components/credential-manager/nubifer-aws-credential-helper
etc/nubifer/shell-integration.sh	components/workspace-manager/shell-integration.sh
usr/local/bin/calamares-detect-tpm.sh	scripts/calamares-detect-tpm.sh
usr/local/bin/calamares-bind-tpm.sh	scripts/calamares-bind-tpm.sh
EOF
)

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

echo "Extracting squashfs from ISO..."
xorriso -osirrox on -indev "$ISO" -extract /live/filesystem.squashfs \
    "$WORK/fs.squashfs" >/dev/null 2>&1 || {
        echo "ERROR: could not extract squashfs (unexpected ISO layout)"; exit 2; }

# Extract only the mapped install paths
EXTRACT_LIST=$(echo "$MAP" | awk -F'\t' '{print $1}')
unsquashfs -q -d "$WORK/fs" -f "$WORK/fs.squashfs" $EXTRACT_LIST >/dev/null 2>&1 || true

echo "=== Build-fidelity check (ISO contents vs source @ ${COMMIT}) ==="
FAIL=0
CHECKED=0
while IFS=$'\t' read -r inst repo; do
    [ -n "$inst" ] || continue
    iso_file="$WORK/fs/$inst"
    if [ ! -f "$iso_file" ]; then
        # A mapped file absent from the ISO is itself a fidelity failure
        # IF the source has it at this commit (i.e. it should have shipped).
        if git cat-file -e "${COMMIT}:${repo}" 2>/dev/null; then
            echo "✗ MISSING from ISO: $inst  (source has $repo @ $COMMIT)"
            FAIL=1
        fi
        continue
    fi
    CHECKED=$((CHECKED + 1))
    if git show "${COMMIT}:${repo}" 2>/dev/null | cmp -s - "$iso_file"; then
        echo "✓ $inst"
    else
        echo "✗ MISMATCH: $inst  !=  ${repo} @ ${COMMIT}"
        FAIL=1
    fi
done <<< "$MAP"
echo "Checked $CHECKED file(s)."

echo ""
echo "=== Staleness check (built commit vs ${TRUNK_REF}) ==="
if git cat-file -e "${TRUNK_REF}^{commit}" 2>/dev/null; then
    STALE=0
    while IFS=$'\t' read -r inst repo; do
        [ -n "$repo" ] || continue
        if ! git diff --quiet "${COMMIT}" "${TRUNK_REF}" -- "$repo" 2>/dev/null; then
            echo "::warning::security-critical file changed on ${TRUNK_REF} since this ISO was built: ${repo} — rebuild to include it"
            STALE=1
        fi
    done <<< "$MAP"
    [ "$STALE" = 0 ] && echo "✓ ISO is current with ${TRUNK_REF} on all tracked files"
else
    echo "(${TRUNK_REF} not available — skipping staleness check)"
fi

echo ""
if [ "$FAIL" = 0 ]; then
    echo "PASS: ISO contents faithful to source @ ${COMMIT}"
    exit 0
fi
echo "FAIL: ISO contents diverge from source — a build step altered or dropped files"
exit 1
