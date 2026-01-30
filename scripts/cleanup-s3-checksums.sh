#!/bin/bash
# One-time cleanup script to remove old checksum files from S3
# These were created with commit SHA suffixes and are no longer needed

set -e

ISO_BUCKET="${ISO_BUCKET:-nubiferos-iso}"
AWS_REGION="${AWS_REGION:-us-east-1}"

echo "=========================================="
echo "S3 Checksum Cleanup Script"
echo "=========================================="
echo ""
echo "Bucket: $ISO_BUCKET"
echo "Region: $AWS_REGION"
echo ""

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &>/dev/null; then
    echo "❌ ERROR: AWS CLI not configured or no valid credentials"
    echo ""
    echo "Please configure AWS credentials using the NubiferOS credential manager:"
    echo "  nubifer-creds add -t aws -n default"
    echo ""
    echo "Or activate a workspace with credentials:"
    echo "  nubifer-workspace switch <workspace-id>"
    echo ""
    exit 1
fi

echo "✓ AWS credentials configured"
echo ""

# Check if bucket exists
if ! aws s3 ls "s3://$ISO_BUCKET" &>/dev/null; then
    echo "❌ ERROR: Cannot access bucket: $ISO_BUCKET"
    echo ""
    echo "Please check:"
    echo "  1. Bucket name is correct"
    echo "  2. You have permissions to access it"
    echo "  3. Bucket is in region: $AWS_REGION"
    echo ""
    exit 1
fi

echo "✓ Bucket accessible"
echo ""

# Find all checksum files with commit SHA suffixes
echo "Searching for old checksum files..."
echo ""

CHECKSUM_FILES=$(aws s3 ls "s3://$ISO_BUCKET/" --recursive | grep -E '(SHA256SUMS|MD5SUMS)-[a-f0-9]{7}' | awk '{print $4}' || true)

if [ -z "$CHECKSUM_FILES" ]; then
    echo "✓ No old checksum files found - bucket is already clean!"
    echo ""
    exit 0
fi

# Count files
FILE_COUNT=$(echo "$CHECKSUM_FILES" | wc -l)

echo "Found $FILE_COUNT old checksum files:"
echo ""
echo "$CHECKSUM_FILES" | head -20
if [ $FILE_COUNT -gt 20 ]; then
    echo "... and $((FILE_COUNT - 20)) more"
fi
echo ""

# Ask for confirmation
read -p "Delete these $FILE_COUNT files? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo ""
    echo "Cleanup cancelled"
    exit 0
fi

echo ""
echo "Deleting old checksum files..."
echo ""

DELETED=0
FAILED=0

while IFS= read -r file; do
    if [ -n "$file" ]; then
        echo -n "  Deleting: $file ... "
        if aws s3 rm "s3://$ISO_BUCKET/$file" 2>&1 | grep -q "delete:"; then
            echo "✓"
            DELETED=$((DELETED + 1))
        else
            echo "✗ FAILED"
            FAILED=$((FAILED + 1))
        fi
    fi
done <<< "$CHECKSUM_FILES"

echo ""
echo "=========================================="
echo "Cleanup Complete!"
echo "=========================================="
echo ""
echo "Deleted: $DELETED files"
if [ $FAILED -gt 0 ]; then
    echo "Failed: $FAILED files"
fi
echo ""

# Show remaining checksum files
echo "Remaining checksum files:"
aws s3 ls "s3://$ISO_BUCKET/" --recursive | grep -E '(SHA256SUMS|MD5SUMS)' || echo "  (none)"
echo ""

echo "✓ S3 bucket cleaned up successfully!"
