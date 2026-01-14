# GitHub Actions + S3 Setup Guide

This guide will help you set up automated ISO builds using GitHub Actions with S3 storage.

## Prerequisites

- GitHub repository (private or public)
- AWS account
- AWS CLI installed locally (optional, for testing)

## Step 1: Create S3 Bucket

1. Go to AWS Console → S3
2. Click "Create bucket"
3. **Bucket name**: `nubiferos-releases` (or your preferred name)
4. **Region**: Choose closest to you (e.g., `us-east-1`)
5. **Block Public Access**: Keep all blocked (we'll use presigned URLs)
6. Click "Create bucket"

## Step 2: Set Up GitHub OIDC Provider in AWS (Recommended - No Keys!)

This method is more secure - no long-lived credentials!

### 2.1: Create OIDC Identity Provider

1. Go to AWS Console → IAM → Identity providers
2. Click "Add provider"
3. **Provider type**: OpenID Connect
4. **Provider URL**: `https://token.actions.githubusercontent.com`
5. Click "Get thumbprint"
6. **Audience**: `sts.amazonaws.com`
7. Click "Add provider"

### 2.2: Create IAM Role

1. Go to IAM → Roles → Create role
2. **Trusted entity type**: Web identity
3. **Identity provider**: token.actions.githubusercontent.com
4. **Audience**: sts.amazonaws.com
5. Click "Next"

### 2.3: Create and Attach Policy

Click "Create policy" and use this JSON (replace YOUR_GITHUB_ORG and YOUR_REPO):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::nubiferos-releases",
        "arn:aws:s3:::nubiferos-releases/*"
      ]
    }
  ]
}
```

1. Name it: `GitHubActionsNubiferOSS3Policy`
2. Create policy
3. Go back to role creation and attach this policy
4. Click "Next"

### 2.4: Configure Trust Policy

**Role name**: `GitHubActionsNubiferOSRole`

After creating, edit the trust policy:

1. Click on the role
2. Go to "Trust relationships" tab
3. Click "Edit trust policy"
4. Replace with this (update YOUR_GITHUB_ORG and YOUR_REPO):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::YOUR_AWS_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_ORG/YOUR_REPO:*"
        }
      }
    }
  ]
}
```

**Find your AWS Account ID**: Click your name in top-right → Copy account ID

5. Click "Update policy"
6. **Copy the Role ARN** (looks like: `arn:aws:iam::123456789012:role/GitHubActionsNubiferOSRole`)

---

## Alternative: IAM User with Access Keys (Less Secure)

<details>
<summary>Click to expand if you prefer using access keys instead of OIDC</summary>

### Create IAM User

1. Go to AWS Console → IAM → Users
2. Click "Create user"
3. **User name**: `github-actions-nubiferos`
4. Click "Next"
5. Attach the `GitHubActionsNubiferOSS3Policy` created above
6. Click "Create user"

### Get Access Keys

1. Click on the user
2. Go to "Security credentials" tab
3. Click "Create access key"
4. Choose "Application running outside AWS"
5. Click "Next" → "Create access key"
6. **IMPORTANT**: Copy both keys (you won't see the secret again!)

</details>

## Step 3: Add Secret to GitHub

1. Go to your GitHub repository
2. Click "Settings" → "Secrets and variables" → "Actions"
3. Click "New repository secret"

**For OIDC (Recommended):**
- Name: `AWS_ROLE_ARN`
- Value: (paste your role ARN from Step 2.4)
  - Example: `arn:aws:iam::123456789012:role/GitHubActionsNubiferOSRole`

**For Access Keys (Alternative):**
- Name: `AWS_ACCESS_KEY_ID`
- Value: (paste your access key ID)
- Name: `AWS_SECRET_ACCESS_KEY`
- Value: (paste your secret access key)

## Step 4: Update Workflow Configuration

Edit `.github/workflows/build-iso.yml` if needed:

```yaml
env:
  ISO_BUCKET: nubiferos-releases  # Change to your bucket name
  AWS_REGION: us-east-1  # Change to your region
```

## Step 5: Test the Workflow

### Option A: Push to main branch
```bash
git add .
git commit -m "Add GitHub Actions workflow"
git push origin main
```

### Option B: Manual trigger
1. Go to GitHub → Actions tab
2. Click "Build NubiferOS ISO"
3. Click "Run workflow"
4. Select branch
5. Click "Run workflow"

## Step 6: Monitor the Build

1. Go to Actions tab in GitHub
2. Click on the running workflow
3. Watch the build progress
4. Build takes ~2-4 hours

## Step 7: Download Your ISO

After build completes:

### Method 1: From GitHub Summary
1. Click on the completed workflow run
2. Scroll to bottom - see the summary with download URL
3. Copy the presigned URL (valid for 7 days)
4. Download with wget or browser:
   ```bash
   wget "PRESIGNED_URL" -O nubiferos.iso
   ```

### Method 2: From S3 directly (if you have AWS CLI)
```bash
# List available versions
aws s3 ls s3://nubiferos-releases/

# Download specific version
aws s3 cp s3://nubiferos-releases/0.1.0-alpha/nubiferos-*.iso ./

# Download checksums
aws s3 cp s3://nubiferos-releases/0.1.0-alpha/SHA256SUMS ./
```

### Method 3: From GitHub Artifacts (backup, 7 days only)
1. Go to workflow run
2. Scroll to "Artifacts" section
3. Click to download (note: GitHub zips it)

## Verify Your Download

```bash
# Verify SHA256
sha256sum -c SHA256SUMS

# Or manually
sha256sum nubiferos-*.iso
```

## Cost Estimate

### S3 Storage
- ~5 GB ISO × $0.023/GB/month = **$0.12/month per ISO**
- Keep 3-5 versions = **$0.36-$0.60/month**

### S3 Transfer
- Download to 5 machines × 5 GB = 25 GB
- First 100 GB/month free
- **Cost: $0** (under free tier)

### GitHub Actions
- Public repo: **FREE** (2,000 minutes/month)
- Private repo: **FREE** for first 2,000 minutes
- After: $0.008/minute (~$2/build)

**Total monthly cost: ~$0.50-$1.00** (mostly S3 storage)

## Optimization Tips

### Reduce Storage Costs
1. Delete old ISOs:
   ```bash
   aws s3 rm s3://nubiferos-releases/0.1.0-alpha/ --recursive
   ```

2. Use S3 Lifecycle rules:
   - Go to S3 bucket → Management → Lifecycle rules
   - Delete objects older than 30 days
   - Or move to Glacier after 7 days

### Speed Up Builds
1. Use GitHub's larger runners (costs extra):
   ```yaml
   runs-on: ubuntu-latest-8-cores
   ```

2. Cache Debian packages (add to workflow):
   ```yaml
   - uses: actions/cache@v3
     with:
       path: /var/cache/apt/archives
       key: ${{ runner.os }}-apt-${{ hashFiles('**/build-nubiferos.sh') }}
   ```

## Troubleshooting

### Build fails with "No space left on device"
- GitHub runners have ~14 GB free space
- The workflow already cleans up unnecessary files
- If still failing, consider:
  - Using self-hosted runner
  - Splitting build into stages
  - Using AWS EC2 instead

### S3 upload fails
- Check AWS credentials are correct
- Verify IAM policy has correct permissions
- Check bucket name matches in workflow

### Can't download ISO
- Presigned URLs expire after 7 days
- Generate new one:
  ```bash
  aws s3 presign s3://nubiferos-releases/0.1.0-alpha/nubiferos-*.iso --expires-in 604800
  ```

### Build takes too long
- Normal: 2-4 hours on GitHub runners
- Consider AWS EC2 spot instance for faster builds
- Or use self-hosted runner with better specs

## Security Notes

1. **Never commit AWS credentials** to git
2. Use IAM user with minimal permissions (only S3 access)
3. Keep S3 bucket private (use presigned URLs for sharing)
4. Rotate AWS access keys periodically
5. Enable S3 bucket versioning for safety
6. Consider enabling S3 bucket encryption

## Next Steps

1. Set up S3 bucket lifecycle rules to auto-delete old ISOs
2. Create a simple download page (static HTML in S3)
3. Set up CloudFront CDN for faster downloads (optional)
4. Add build notifications (Slack, Discord, email)

## Alternative: GitHub Releases (Simpler but Limited)

If you don't want to use S3, you can use GitHub Releases:

**Pros:**
- Simpler setup
- No AWS account needed
- Free for public repos

**Cons:**
- 2 GB file size limit (your ISO might be too big!)
- Slower downloads
- Less control

To use GitHub Releases instead, replace the S3 upload step with:
```yaml
- name: Create Release
  uses: softprops/action-gh-release@v1
  if: startsWith(github.ref, 'refs/tags/')
  with:
    files: |
      output/*.iso
      output/SHA256SUMS
```

## Questions?

Check the workflow logs in GitHub Actions for detailed error messages.
