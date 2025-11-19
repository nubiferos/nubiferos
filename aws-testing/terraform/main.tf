# NubiferOS AWS Testing Infrastructure
# Terraform configuration for automated ISO testing pipeline

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# S3 Bucket for ISO storage
resource "aws_s3_bucket" "iso_bucket" {
  bucket = var.iso_bucket_name
  
  tags = {
    Name        = "NubiferOS ISO Builds"
    Purpose     = "ISO Storage"
    Environment = "Testing"
  }
}

resource "aws_s3_bucket_versioning" "iso_bucket_versioning" {
  bucket = aws_s3_bucket.iso_bucket.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "iso_bucket_encryption" {
  bucket = aws_s3_bucket.iso_bucket.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 Bucket for Terraform state
resource "aws_s3_bucket" "terraform_state" {
  bucket = "${var.iso_bucket_name}-terraform-state"
  
  tags = {
    Name    = "Terraform State"
    Purpose = "Infrastructure State"
  }
}

# VM Import Service Role
resource "aws_iam_role" "vmimport" {
  name = "vmimport"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "vmie.amazonaws.com"
      }
      Action = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "sts:ExternalId" = "vmimport"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "vmimport_policy" {
  name = "vmimport-policy"
  role = aws_iam_role.vmimport.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.iso_bucket.arn,
          "${aws_s3_bucket.iso_bucket.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:ModifySnapshotAttribute",
          "ec2:CopySnapshot",
          "ec2:RegisterImage",
          "ec2:Describe*"
        ]
        Resource = "*"
      }
    ]
  })
}

# CodeBuild IAM Role
resource "aws_iam_role" "codebuild_role" {
  name = "nubiferos-codebuild-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "codebuild.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "codebuild_policy" {
  name = "nubiferos-codebuild-policy"
  role = aws_iam_role.codebuild_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetBucketLocation",
          "s3:ListBucket",
          "s3:PutObject"
        ]
        Resource = [
          aws_s3_bucket.iso_bucket.arn,
          "${aws_s3_bucket.iso_bucket.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:*",
          "ssm:PutParameter",
          "ssm:GetParameter"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:PutRolePolicy",
          "iam:GetRole"
        ]
        Resource = "arn:aws:iam::*:role/vmimport"
      }
    ]
  })
}

# CodePipeline IAM Role
resource "aws_iam_role" "codepipeline_role" {
  name = "nubiferos-codepipeline-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "codepipeline.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "nubiferos-codepipeline-policy"
  role = aws_iam_role.codepipeline_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketLocation",
          "s3:GetBucketVersioning",
          "s3:ListBucket",
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = [
          aws_s3_bucket.iso_bucket.arn,
          "${aws_s3_bucket.iso_bucket.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "codestar-connections:UseConnection"
        ]
        Resource = var.codestar_connection_arn
      }
    ]
  })
}

# CodeBuild Project - Import ISO
resource "aws_codebuild_project" "import_iso" {
  name          = "nubiferos-import-iso"
  service_role  = aws_iam_role.codebuild_role.arn
  
  artifacts {
    type = "CODEPIPELINE"
  }
  
  environment {
    compute_type                = "BUILD_GENERAL1_LARGE"
    image                      = "aws/codebuild/standard:7.0"
    type                       = "LINUX_CONTAINER"
    privileged_mode            = false
    
    environment_variable {
      name  = "ISO_BUCKET"
      value = aws_s3_bucket.iso_bucket.id
    }
  }
  
  source {
    type      = "CODEPIPELINE"
    buildspec = "aws-testing/codebuild/import-iso-buildspec.yml"
  }
}

# CodeBuild Project - Deploy Instance
resource "aws_codebuild_project" "deploy_instance" {
  name          = "nubiferos-deploy-instance"
  service_role  = aws_iam_role.codebuild_role.arn
  
  artifacts {
    type = "CODEPIPELINE"
  }
  
  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                      = "aws/codebuild/standard:7.0"
    type                       = "LINUX_CONTAINER"
    privileged_mode            = false
    
    environment_variable {
      name  = "INSTANCE_TYPE"
      value = var.instance_type
    }
    
    environment_variable {
      name  = "SECURITY_GROUP_ID"
      value = aws_security_group.nice_dcv.id
    }
  }
  
  source {
    type      = "CODEPIPELINE"
    buildspec = "aws-testing/codebuild/deploy-instance-buildspec.yml"
  }
}

# Security Group for NICE DCV
resource "aws_security_group" "nice_dcv" {
  name        = "nubiferos-nice-dcv"
  description = "Allow NICE DCV access"
  
  ingress {
    description = "NICE DCV"
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }
  
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "nubiferos-nice-dcv"
  }
}

# CodePipeline
resource "aws_codepipeline" "nubiferos_pipeline" {
  name     = "nubiferos-test-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn
  
  artifact_store {
    location = aws_s3_bucket.iso_bucket.bucket
    type     = "S3"
  }
  
  stage {
    name = "Source"
    
    action {
      name             = "ISOSource"
      category         = "Source"
      owner            = "AWS"
      provider         = "S3"
      version          = "1"
      output_artifacts = ["iso_output"]
      
      configuration = {
        S3Bucket             = aws_s3_bucket.iso_bucket.bucket
        S3ObjectKey          = "nubiferos-latest.iso"
        PollForSourceChanges = true
      }
    }
    
    action {
      name             = "RepoSource"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["repo_output"]
      
      configuration = {
        ConnectionArn    = var.codestar_connection_arn
        FullRepositoryId = var.github_repo
        BranchName       = var.github_branch
      }
    }
  }
  
  stage {
    name = "ImportISO"
    
    action {
      name             = "ImportToAMI"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["repo_output", "iso_output"]
      output_artifacts = ["import_output"]
      
      configuration = {
        ProjectName   = aws_codebuild_project.import_iso.name
        PrimarySource = "repo_output"
      }
    }
  }
  
  stage {
    name = "DeployTest"
    
    action {
      name            = "LaunchInstance"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["import_output"]
      
      configuration = {
        ProjectName = aws_codebuild_project.deploy_instance.name
      }
    }
  }
}
