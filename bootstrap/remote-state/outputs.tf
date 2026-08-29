output "bucket_name" {
  description = "S3 bucket storing Terraform state."
  value       = aws_s3_bucket.state.id
}
