# One-time bootstrap: creates the versioned S3 state bucket for an account.
# Standalone on purpose (does not include root) so remote_state doesn't point
# at the bucket it's creating. Run once per account before any other stack.

locals {
  aws_region = "us-east-1"

  # Injected via env var; must match what environments use.
  account_id = get_env("AWS_ACCOUNT_ID", "")
}

# Generate the AWS provider (no root include to inherit from).
generate "provider_aws" {
  path      = "provider_aws.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "${local.aws_region}"
}
EOF
}

terraform {
  # Local module dir; one-off setup stack with a local backend.
  source = "."
}

# Variables passed to the bootstrap module.
inputs = {
  account_id  = local.account_id
  aws_region  = local.aws_region
  bucket_name = "eks-tf-state-${local.account_id}"
}
