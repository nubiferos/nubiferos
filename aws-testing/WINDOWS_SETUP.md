# Windows Setup Guide for CodeBuild ISO Testing

Quick guide for setting up CodeBuild ISO testing on Windows.

## Prerequisites

1. **AWS CLI** installed
   - Download: https://aws.amazon.com/cli/
   - Verify: `aws --version`

2. **AWS Credentials** configured
   - Run: `aws configure`
   - Enter your Access Key ID and Secret Access Key

## Option 1: PowerShell Script (Automated)

Run the PowerShell script:

```powershell
cd aws-testing
.\setup-codebuild.ps1
```

This will:
- Create IAM role
- Create CodeBuild project
- Run a test build

## Option 2: Manual Setup (Step-by-Step)

### Step 1: Get Your AWS Account ID

```powershell
aws sts get-caller-identity --query Account --output text
```

Save this as `$ACCOUNT_ID` for later steps.

### Step 2: Create IAM Role

**Create trust policy file** (`trust-policy.json`):
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

**Create the role:**
```powershell
aws iam create-role `
  --role-name CodeBuildNubiferOSRole `
  --assume-role-policy-document file://trust-policy.json
```

**Create permissions policy file** (`permissions-policy.json`):
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::nubiferos-iso",
        "arn:aws:s3:::nubiferos-iso/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    }
  ]
}
```

**Attach policy to role:**
```powershell
aws iam put-role-policy `
  --role-name CodeBuildNubiferOSRole `
  --policy-name CodeBuildNubiferOSPolicy `
  --policy-document file://permissions-policy.json
```

**Wait for IAM propagation:**
```powershell
Start-Sleep -Seconds 10
```

### Step 3: Create CodeBuild Project

```powershell
aws codebuild create-project `
  --name nubiferos-test-iso `
  --description "Test NubiferOS ISO with QEMU" `
  --source "type=GITHUB,location=https://github.com/nubiferos/nubiferos.git,buildspec=aws-testing/codebuild/test-iso-buildspec.yml" `
  --artifacts "type=NO_ARTIFACTS" `
  --environment "type=LINUX_CONTAINER,image=aws/codebuild/standard:7.0,computeType=BUILD_GENERAL1_LARGE" `
  --service-role "arn:aws:iam::YOUR_ACCOUNT_ID:role/CodeBuildNubiferOSRole" `
  --timeout-in-minutes 15
```

**Replace `YOUR_ACCOUNT_ID`** with your actual account ID from Step 1.

### Step 4: Set Environment Variables

```powershell
aws codebuild update-project `
  --name nubiferos-test-iso `
  --environment "type=LINUX_CONTAINER,image=aws/codebuild/standard:7.0,computeType=BUILD_GENERAL1_LARGE,environmentVariables=[{name=ISO_BUCKET,value=nubiferos-iso,type=PLAINTEXT},{name=ISO_KEY,value=1.0/NubiferOS-1.0-amd64.iso,type=PLAINTEXT}]"
```

### Step 5: Test the Build

**Start a build:**
```powershell
$BUILD_ID = aws codebuild start-build `
  --project-name nubiferos-test-iso `
  --query 'build.id' `
  --output text

Write-Host "Build ID: $BUILD_ID"
```

**Watch the logs:**
```powershell
aws logs tail /aws/codebuild/nubiferos-test-iso --follow
```

**Check build status:**
```powershell
aws codebuild batch-get-builds --ids $BUILD_ID
```

**Wait for completion:**
```powershell
aws codebuild wait build-complete --ids $BUILD_ID
```

**Get final status:**
```powershell
aws codebuild batch-get-builds `
  --ids $BUILD_ID `
  --query 'builds[0].buildStatus' `
  --output text
```

## Configuration

### Change ISO Bucket/Key

Update environment variables:

```powershell
aws codebuild update-project `
  --name nubiferos-test-iso `
  --environment "type=LINUX_CONTAINER,image=aws/codebuild/standard:7.0,computeType=BUILD_GENERAL1_LARGE,environmentVariables=[{name=ISO_BUCKET,value=YOUR_BUCKET,type=PLAINTEXT},{name=ISO_KEY,value=YOUR_KEY,type=PLAINTEXT}]"
```

### Change Region

Add `--region` to all commands:

```powershell
aws codebuild start-build `
  --project-name nubiferos-test-iso `
  --region us-west-2
```

## Common Commands

### Trigger a Build

```powershell
aws codebuild start-build --project-name nubiferos-test-iso
```

### View Logs

```powershell
aws logs tail /aws/codebuild/nubiferos-test-iso --follow
```

### List Recent Builds

```powershell
aws codebuild list-builds-for-project `
  --project-name nubiferos-test-iso `
  --max-items 10
```

### Get Build Details

```powershell
aws codebuild batch-get-builds --ids BUILD_ID
```

### Delete Project

```powershell
# Delete CodeBuild project
aws codebuild delete-project --name nubiferos-test-iso

# Delete IAM policy
aws iam delete-role-policy `
  --role-name CodeBuildNubiferOSRole `
  --policy-name CodeBuildNubiferOSPolicy

# Delete IAM role
aws iam delete-role --role-name CodeBuildNubiferOSRole
```

## Troubleshooting

### AWS CLI Not Found

**Error:** `aws : The term 'aws' is not recognized`

**Fix:** Install AWS CLI from https://aws.amazon.com/cli/

### Credentials Not Configured

**Error:** `Unable to locate credentials`

**Fix:** Run `aws configure` and enter your credentials

### Role Already Exists

**Error:** `EntityAlreadyExists`

**Fix:** Either delete the existing role or use it:
```powershell
aws iam delete-role-policy --role-name CodeBuildNubiferOSRole --policy-name CodeBuildNubiferOSPolicy
aws iam delete-role --role-name CodeBuildNubiferOSRole
```

### Project Already Exists

**Error:** `ResourceAlreadyExistsException`

**Fix:** Delete the existing project:
```powershell
aws codebuild delete-project --name nubiferos-test-iso
```

### Build Fails

**Check logs:**
```powershell
aws logs tail /aws/codebuild/nubiferos-test-iso
```

**Common issues:**
- ISO not in S3 bucket
- Wrong ISO_BUCKET or ISO_KEY
- IAM permissions missing

## Integration with GitHub Actions

After setup, trigger builds from GitHub Actions:

```yaml
- name: Trigger CodeBuild Test
  env:
    AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
    AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
  run: |
    $BUILD_ID = aws codebuild start-build `
      --project-name nubiferos-test-iso `
      --query 'build.id' `
      --output text
    
    Write-Host "Build started: $BUILD_ID"
    
    aws codebuild wait build-complete --ids $BUILD_ID
    
    $STATUS = aws codebuild batch-get-builds `
      --ids $BUILD_ID `
      --query 'builds[0].buildStatus' `
      --output text
    
    if ($STATUS -ne "SUCCEEDED") {
      Write-Host "Build failed: $STATUS"
      exit 1
    }
```

## Next Steps

1. ✅ Set up CodeBuild project
2. ✅ Test with a build
3. ✅ Integrate with GitHub Actions
4. ✅ Monitor builds in AWS Console

## AWS Console

You can also manage CodeBuild in the AWS Console:

1. Go to: https://console.aws.amazon.com/codebuild/
2. Select your region
3. Find project: `nubiferos-test-iso`
4. Click "Start build" to trigger manually
5. View logs and build history

---

**Tip:** Use the PowerShell script (`setup-codebuild.ps1`) for easiest setup!
