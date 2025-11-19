# Variables for NubiferOS AWS Testing Infrastructure

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "iso_bucket_name" {
  description = "S3 bucket name for ISO storage"
  type        = string
  default     = "nubiferos-iso-builds"
}

variable "instance_type" {
  description = "EC2 instance type for testing"
  type        = string
  default     = "t3.large"
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access NICE DCV"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Change to your IP for security
}

variable "auto_terminate_hours" {
  description = "Hours before test instance auto-terminates"
  type        = number
  default     = 4
}

variable "github_repo" {
  description = "GitHub repository (owner/repo)"
  type        = string
  default     = "jessetop/nubiferOS"
}

variable "github_branch" {
  description = "GitHub branch to use"
  type        = string
  default     = "trunk"
}

variable "github_token" {
  description = "GitHub personal access token for CodePipeline"
  type        = string
  sensitive   = true
}
