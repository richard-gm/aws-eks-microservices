variable "account_id" {
  description = "AWS account id the state bucket is created in."
  type        = string
}

variable "aws_region" {
  description = "AWS region where the state bucket is created."
  type        = string
}

variable "bucket_name" {
  description = "Name of the S3 bucket that will store Terraform state."
  type        = string
}
