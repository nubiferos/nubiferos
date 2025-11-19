#!/bin/bash
# Setup CodeBuild project for ISO testing

set -e

PROJECT_NAME="nubiferos-test-iso"
AWS_REGION="${AWS_REGION:-us-east-1}"
ISO_BUCKET="${ISO_BUCKET:-nubiferos-iso}"

echo "=========================================="
echo "CodeBuild Setup for NubiferOS ISO Testing"
echo "=========================================="
echo ""
echo "Project Name: $PROJECT_NAME"
echo "AWS Region: $AWS_REGION"
echo "ISO Bucket: $ISO_BUCKET"
echo ""

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI not installed"
    echo "Install from: https://aws.amazon.com/cli/"
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS credentials not configured"
    echo "Run: aws configure"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "✅ AWS Account: $ACCOUNT_ID"
echo ""

# Check if project exists
if aws codebuild batch-get-projects --names $PROJECT_NAME &> /dev/null; then
    echo "⚠️  CodeBuild project '$PROJECT_NAME' already exists"
    read -p "Delete and recreate? [y/N] " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Deleting existing project..."
        aws codebuild delete-project --name $PROJECT_NAME
        echo "✅ Deleted"
    else
        echo "Exiting..."
        exit 0
    fi
fi

# Create IAM role if it doesn't exist
ROLE_NAME="CodeBuildNubiferOSRole"
ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"

if ! aws iam get-role --role-name $ROLE_NAME &> /dev/null; then
    echo "Creating IAM role: $ROLE_NAME"
    
    # Trust policy
    cat > /tmp/trust-policy.json <<EOF
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
EOF
    
    aws iam create-role \
        --role-name $ROLE_NAME \
        --assume-role-policy-document file:///tmp/trust-policy.json
    
    # Permissions policy
    cat > /tmp/permissions-policy.json <<EOF
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
EOF
    
    aws iam put-role-policy \
        --role-name $ROLE_NAME \
        --policy-name CodeBuildNubiferOSPolicy \
        --policy-document file:///tmp/permissions-policy.json
    
    echo "✅ IAM role created"
    echo "Waiting 10 seconds for IAM propagation..."
    sleep 10
else
    echo "✅ IAM role exists: $ROLE_NAME"
fi

# Create CodeBuild project
echo ""
echo "Creating CodeBuild project..."

aws codebuild create-project \
    --name $PROJECT_NAME \
    --description "Test NubiferOS ISO with QEMU" \
    --source type=GITHUB,location=https://github.com/nubiferos/nubiferos.git,buildspec=aws-testing/codebuild/test-iso-buildspec.yml \
    --artifacts type=NO_ARTIFACTS \
    --environment type=LINUX_CONTAINER,image=aws/codebuild/standard:7.0,computeType=BUILD_GENERAL1_LARGE,privilegedMode=false \
    --service-role $ROLE_ARN \
    --timeout-in-minutes 15 \
    --region $AWS_REGION \
    --environment-variables-override \
        name=ISO_BUCKET,value=$ISO_BUCKET,type=PLAINTEXT \
        name=ISO_KEY,value=1.0/NubiferOS-1.0-amd64.iso,type=PLAINTEXT

echo "✅ CodeBuild project created"
echo ""

# Test the project
echo "=========================================="
echo "Testing CodeBuild Project"
echo "=========================================="
echo ""
echo "Starting test build..."

BUILD_ID=$(aws codebuild start-build \
    --project-name $PROJECT_NAME \
    --region $AWS_REGION \
    --query 'build.id' \
    --output text)

echo "Build ID: $BUILD_ID"
echo ""
echo "View logs:"
echo "  aws logs tail /aws/codebuild/$PROJECT_NAME --follow"
echo ""
echo "Check status:"
echo "  aws codebuild batch-get-builds --ids $BUILD_ID"
echo ""
echo "Waiting for build to complete..."

# Wait for build
aws codebuild wait build-complete --ids $BUILD_ID --region $AWS_REGION

# Get result
STATUS=$(aws codebuild batch-get-builds \
    --ids $BUILD_ID \
    --region $AWS_REGION \
    --query 'builds[0].buildStatus' \
    --output text)

echo ""
if [ "$STATUS" = "SUCCEEDED" ]; then
    echo "✅ Build SUCCEEDED"
else
    echo "❌ Build $STATUS"
    echo ""
    echo "Check logs for details:"
    echo "  aws logs tail /aws/codebuild/$PROJECT_NAME"
    exit 1
fi

echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "CodeBuild project: $PROJECT_NAME"
echo "IAM role: $ROLE_NAME"
echo "Region: $AWS_REGION"
echo ""
echo "To trigger a build:"
echo "  aws codebuild start-build --project-name $PROJECT_NAME"
echo ""
echo "To view logs:"
echo "  aws logs tail /aws/codebuild/$PROJECT_NAME --follow"
echo ""
echo "To delete project:"
echo "  aws codebuild delete-project --name $PROJECT_NAME"
echo "  aws iam delete-role-policy --role-name $ROLE_NAME --policy-name CodeBuildNubiferOSPolicy"
echo "  aws iam delete-role --role-name $ROLE_NAME"
echo ""
