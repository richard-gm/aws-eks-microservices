# Environment: dev. Inherits root remote_state + provider.
include {
  path = find_in_parent_folders()
}

# dev-specific values; override root defaults via try(local.x, default).
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

# No top-level `inputs` here: it would be passed to every module and cause errors.
