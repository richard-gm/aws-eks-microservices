# Environment: dev. Per-env values + the AWS provider for this environment.
#
# This is a flat *partial* (no include, no inputs, no terraform.source):
# Terragrunt allows only one level of includes, so instead of chaining this
# config through root (unit -> env -> root would be a 3-level include, which
# Terragrunt rejects), leaf units pull it in with
#   include "env" { path = find_in_parent_folders("env.hcl"); expose = true }

locals {
  env        = "dev"
  aws_region = "us-east-1"

  # Injected at runtime via env var; never hardcoded in version control.
  account_id = get_env("AWS_ACCOUNT_ID", "")

  # One VPC per env; CIDRs differ from prod to avoid overlap.
  vpc_cidr             = "10.0.0.0/16"
  availability_zones   = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnet_cidrs = ["10.0.0.0/20", "10.0.16.0/20", "10.0.32.0/20"]
  public_subnet_cidrs  = ["10.0.240.0/22", "10.0.244.0/22", "10.0.248.0/22"]

  # EKS control plane settings.
  cluster_name      = "eks-${local.env}" # => "eks-dev"
  cluster_version   = "1.30"
  karpenter_version = "1.0.0"
  argocd_version    = "7.2.0"

  # GitOps source of truth; injected via env var (placeholder is local fallback).
  git_repo_url = get_env("GIT_REPO_URL", "https://github.com/your-org/aws-monitoring-scripts.git")

  # ArgoCD syncs this env from this branch (same repo, different revision).
  git_repo_branch = "develop"
}

# The AWS provider is per-env (region + Environment tag), so it's generated here
# from this config's own locals and shared by every unit that includes env.hcl.
generate "provider_aws" {
  path      = "provider_aws.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
terraform {
  required_version = ">= 1.10.0"   # native S3 locking needs >= 1.10

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "${local.aws_region}"

  default_tags {
    tags = {
      ManagedBy   = "terraform"
      Project     = "eks-platform"
      Environment = "${local.env}"
    }
  }
}
EOF
}