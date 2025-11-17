# Outputs for NubiferOS AWS Testing Infrastructure

output "iso_bucket_name" {
  description = "S3 bucket for ISO uploads"
  value       = aws_s3_bucket.iso_bucket.id
}

output "pipeline_name" {
  description = "CodePipeline name"
  value       = aws_codepipeline.nubiferos_pipeline.name
}

output "security_group_id" {
  description = "Security group for NICE DCV access"
  value       = aws_security_group.nice_dcv.id
}

output "deployment_instructions" {
  description = "Next steps after deployment"
  value       = <<-EOT
    
    ✅ Infrastructure deployed successfully!
    
    Next steps:
    1. Upload ISO to S3:
       aws s3 cp output/nubiferos-1.0-amd64.iso s3://${aws_s3_bucket.iso_bucket.id}/nubiferos-latest.iso
    
    2. Monitor pipeline:
       aws codepipeline get-pipeline-state --name ${aws_codepipeline.nubiferos_pipeline.name}
    
    3. View logs:
       aws logs tail /aws/codebuild/nubiferos-import-iso --follow
    
    4. After deployment, connect to instance:
       - Get IP: aws ec2 describe-instances --filters "Name=tag:Purpose,Values=nubiferos-test"
       - URL: https://<instance-ip>:8443
       - User: live / Pass: live
  EOT
}
