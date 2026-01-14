# S3 Checksum Cleanup

## Problem

The GitHub Actions workflow was uploading checksum files with commit SHA suffixes:
- `SHA256SUMS-abc1234`
- `MD5SUMS-abc1234`

This created a new set of checksum files for every build, cluttering the S3 bucket with hundreds of unnecessary files.

## Solution

### 1. Updated GitHub Workflow

Modified `.github/workflows/build-iso.yml` to:

1. **Clean up old checksums before upload** - Removes any existing checksum files with commit SHA suffixes
2. **Upload checksums without suffix** - Now uploads as `SHA256SUMS` and `MD5SUMS` (no commit SHA)
3. **One set per version** - Each version directory has exactly one set of checksums

### 2. One-Time Cleanup Script

Created `scripts/cleanup-s3-checksums.sh` to clean up existing old checksum files.

## Running the Cleanup

To clean up existing old checksum files in S3:

```bash
# Make sure AWS credentials are configured
aws configure

# Or use environment variables
export AWS_ACCESS_KEY_ID=your_key
export AWS_SECRET_ACCESS_KEY=your_secret

# Run the cleanup script
./scripts/cleanup-s3-checksums.sh
```

The script will:
1. Check AWS credentials
2. Verify bucket access
3. Find all checksum files with commit SHA suffixes
4. Show you what will be deleted
5. Ask for confirmation
6. Delete the old files
7. Show summary of what was cleaned up

## New S3 Structure

### Before (cluttered)
```
s3://nubiferos-iso/
├── 1.0/
│   ├── nubiferos-1.0-20241121-123456-abc1234-amd64.iso
│   ├── SHA256SUMS-abc1234
│   ├── MD5SUMS-abc1234
│   ├── SHA256SUMS-def5678
│   ├── MD5SUMS-def5678
│   ├── SHA256SUMS-ghi9012
│   └── MD5SUMS-ghi9012
```

### After (clean)
```
s3://nubiferos-iso/
├── 1.0/
│   ├── nubiferos-1.0-20241121-123456-abc1234-amd64.iso
│   ├── SHA256SUMS
│   └── MD5SUMS
├── nubiferos-latest.iso
└── nubiferos-latest.iso.sha256
```

## Benefits

1. **Cleaner bucket** - Only one set of checksums per version
2. **Easier to find** - No need to match commit SHA to find the right checksum
3. **Reduced storage** - Fewer files = lower S3 costs
4. **Automatic cleanup** - Old checksums are removed before new ones are uploaded
5. **Consistent naming** - Always `SHA256SUMS` and `MD5SUMS`

## Verification

After running the cleanup, verify the bucket structure:

```bash
# List all checksum files
aws s3 ls s3://nubiferos-iso/ --recursive | grep -E '(SHA256SUMS|MD5SUMS)'

# Should only show:
# - One SHA256SUMS per version directory
# - One MD5SUMS per version directory
# - nubiferos-latest.iso.sha256 at root
```

## Future Builds

All future builds will automatically:
1. Remove old checksums for the version being built
2. Upload new checksums without commit SHA suffix
3. Keep the bucket clean

No manual intervention needed!
