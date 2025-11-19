# Setup CodeBuild project for ISO testing (PowerShell)
#
# NOTE: This script does NOT create S3 buckets.
# The S3 bucket must already exist before running this script.
# It only creates:
#   - IAM role for CodeBuild
#   - CodeBuild project
#   - Environment variables

$ErrorActionPreference = "Stop"

$PROJECT_NAME = "nubiferos-test-iso"

# Get region from environment, AWS CLI config, or default to us-east-1
if ($env:AWS_REGION) {
    $AWS_REGION = $env:AWS_REGION
} else {
    try {
        $AWS_REGION = aws configure get region 2>$null
        if ([string]::IsNullOrWhiteSpace($AWS_REGION)) {
            $AWS_REGION = "us-east-1"
        }
    } catch {
        $AWS_REGION = "us-east-1"
    }
}

$ISO_BUCKET = if ($env:ISO_BUCKET) { $env:ISO_BUCKET } else { "nubiferos-iso-builds" }
$ISO_KEY = if ($env:ISO_KEY) { $env:ISO_KEY } else { "nubiferos-latest.iso" }

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "CodeBuild Setup for NubiferOS ISO Testing" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Project Name: $PROJECT_NAME"
Write-Host "AWS Region: $AWS_REGION"
Write-Host "ISO Bucket: $ISO_BUCKET"
Write-Host ""

# Check AWS CLI
try {
    aws --version | Out-Null
    Write-Host "✅ AWS CLI installed" -ForegroundColor Green
} catch {
    Write-Host "❌ AWS CLI not installed" -ForegroundColor Red
    Write-Host "Install from: https://aws.amazon.com/cli/"
    exit 1
}

# Check AWS credentials
try {
    $ACCOUNT_ID = aws sts get-caller-identity --query Account --output text
    Write-Host "✅ AWS Account: $ACCOUNT_ID" -ForegroundColor Green
} catch {
    Write-Host "❌ AWS credentials not configured" -ForegroundColor Red
    Write-Host "Run: aws configure"
    exit 1
}

Write-Host ""

# Check if project exists
$projectExists = $false
try {
    aws codebuild batch-get-projects --names $PROJECT_NAME 2>$null | Out-Null
    $projectExists = $true
} catch {
    $projectExists = $false
}

if ($projectExists) {
    Write-Host "✅ CodeBuild project already exists: $PROJECT_NAME" -ForegroundColor Green
    Write-Host "Skipping project creation, will use existing project."
    Write-Host ""
}

# Create IAM role if it doesn't exist
$ROLE_NAME = "CodeBuildNubiferOSRole"
$ROLE_ARN = "arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"

$roleExists = $false
try {
    aws iam get-role --role-name $ROLE_NAME 2>$null | Out-Null
    $roleExists = $true
} catch {
    $roleExists = $false
}

if (-not $roleExists) {
    Write-Host "Creating IAM role: $ROLE_NAME"
    
    # Trust policy
    $trustPolicy = @"
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
"@
    
    $trustPolicy | Out-File -FilePath "$env:TEMP\trust-policy.json" -Encoding utf8
    
    aws iam create-role `
        --role-name $ROLE_NAME `
        --assume-role-policy-document "file://$env:TEMP\trust-policy.json"
    
    # Permissions policy
    $permissionsPolicy = @"
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
        "arn:aws:s3:::${ISO_BUCKET}",
        "arn:aws:s3:::${ISO_BUCKET}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:${AWS_REGION}:${ACCOUNT_ID}:log-group:/aws/codebuild/${PROJECT_NAME}:*"
    }
  ]
}
"@
    
    $permissionsPolicy | Out-File -FilePath "$env:TEMP\permissions-policy.json" -Encoding utf8
    
    aws iam put-role-policy `
        --role-name $ROLE_NAME `
        --policy-name CodeBuildNubiferOSPolicy `
        --policy-document "file://$env:TEMP\permissions-policy.json"
    
    Write-Host "✅ IAM role created" -ForegroundColor Green
    Write-Host "Waiting 10 seconds for IAM propagation..."
    Start-Sleep -Seconds 10
} else {
    Write-Host "✅ IAM role exists: $ROLE_NAME" -ForegroundColor Green
}

# Create or update CodeBuild project
if (-not $projectExists) {
    Write-Host ""
    Write-Host "Creating CodeBuild project..."

    aws codebuild create-project `
        --name $PROJECT_NAME `
        --description "Test NubiferOS ISO with QEMU" `
        --source "type=GITHUB,location=https://github.com/nubiferos/nubiferos.git,buildspec=aws-testing/codebuild/test-iso-buildspec.yml" `
        --artifacts "type=NO_ARTIFACTS" `
        --environment "type=LINUX_CONTAINER,image=aws/codebuild/standard:7.0,computeType=BUILD_GENERAL1_LARGE,privilegedMode=false" `
        --service-role $ROLE_ARN `
        --timeout-in-minutes 15 `
        --region $AWS_REGION

    Write-Host "✅ CodeBuild project created" -ForegroundColor Green
    Write-Host ""
}

# Update project configuration (always do this in case it changed)
Write-Host "Updating project configuration..."

# Update buildspec to use the new test-iso-buildspec.yml
aws codebuild update-project `
    --name $PROJECT_NAME `
    --source "type=GITHUB,location=https://github.com/nubiferos/nubiferos.git,buildspec=aws-testing/codebuild/test-iso-buildspec.yml" `
    --region $AWS_REGION

Write-Host "✅ Buildspec updated to test-iso-buildspec.yml" -ForegroundColor Green

# Update environment variables
Write-Host "Setting environment variables..."

# Create environment JSON file
$envVars = @"
{
  "type": "LINUX_CONTAINER",
  "image": "aws/codebuild/standard:7.0",
  "computeType": "BUILD_GENERAL1_LARGE",
  "environmentVariables": [
    {
      "name": "ISO_BUCKET",
      "value": "$ISO_BUCKET",
      "type": "PLAINTEXT"
    },
    {
      "name": "ISO_KEY",
      "value": "$ISO_KEY",
      "type": "PLAINTEXT"
    }
  ]
}
"@

$envVars | Out-File -FilePath "$env:TEMP\environment.json" -Encoding utf8

aws codebuild update-project `
    --name $PROJECT_NAME `
    --environment "file://$env:TEMP\environment.json" `
    --region $AWS_REGION

Write-Host "✅ Environment variables set" -ForegroundColor Green
Write-Host ""

# Test the project
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Testing CodeBuild Project" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Starting test build..."

$BUILD_ID = aws codebuild start-build `
    --project-name $PROJECT_NAME `
    --region $AWS_REGION `
    --query 'build.id' `
    --output text

Write-Host "Build ID: $BUILD_ID"
Write-Host ""
Write-Host "View logs:"
Write-Host "  aws logs tail /aws/codebuild/$PROJECT_NAME --follow" -ForegroundColor Yellow
Write-Host ""
Write-Host "Check status:"
Write-Host "  aws codebuild batch-get-builds --ids $BUILD_ID" -ForegroundColor Yellow
Write-Host ""
Write-Host "Waiting for build to complete..."

# Wait for build
aws codebuild wait build-complete --ids $BUILD_ID --region $AWS_REGION

# Get result
$STATUS = aws codebuild batch-get-builds `
    --ids $BUILD_ID `
    --region $AWS_REGION `
    --query 'builds[0].buildStatus' `
    --output text

Write-Host ""
if ($STATUS -eq "SUCCEEDED") {
    Write-Host "✅ Build SUCCEEDED" -ForegroundColor Green
} else {
    Write-Host "❌ Build $STATUS" -ForegroundColor Red
    Write-Host ""
    Write-Host "Check logs for details:"
    Write-Host "  aws logs tail /aws/codebuild/$PROJECT_NAME"
    exit 1
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Setup Complete!" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "CodeBuild project: $PROJECT_NAME"
Write-Host "IAM role: $ROLE_NAME"
Write-Host "Region: $AWS_REGION"
Write-Host ""
Write-Host "To trigger a build:"
Write-Host "  aws codebuild start-build --project-name $PROJECT_NAME" -ForegroundColor Yellow
Write-Host ""
Write-Host "To view logs:"
Write-Host "  aws logs tail /aws/codebuild/$PROJECT_NAME --follow" -ForegroundColor Yellow
Write-Host ""
Write-Host "To delete project:"
Write-Host "  aws codebuild delete-project --name $PROJECT_NAME" -ForegroundColor Yellow
Write-Host "  aws iam delete-role-policy --role-name $ROLE_NAME --policy-name CodeBuildNubiferOSPolicy" -ForegroundColor Yellow
Write-Host "  aws iam delete-role --role-name $ROLE_NAME" -ForegroundColor Yellow
Write-Host ""
