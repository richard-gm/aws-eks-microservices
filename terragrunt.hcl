# Root Terragrunt config: shared remote_state (S3 native locking) and AWS
# provider, inherited by every unit via include. Env-specific values are
# injected through locals from environments/<env>/terragrunt.hcl.

# Defaults here are overridden by environments/<env>/terragrunt.hcl via
# try(local.x, default) — that is how per-env values flow in.
locals {
  aws_region = try(local.aws_region, "us-east-1")
  account_id = try(local.account_id, "")
  env        = try(local.env, "dev")

  # One state bucket per AWS account.
  state_bucket = "eks-tf-state-${local.account_id}"
}

# Remote state in S3 with native locking (no DynamoDB). Bucket is created
# per-account by bootstrap/remote-state.
remote_state {
  backend = "s3"

  # Generate backend.tf per unit from this single template.
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = {
    bucket = local.state_bucket
    # Per-unit state key, e.g. environments/dev/vpc/terraform.tfstate.
    key          = "${path_relative_to_include()}/terraform.tfstate"
    region       = local.aws_region
    use_lockfile = true # native S3 locking, no DynamoDB
    encrypt      = true
  }
}

# Generate the AWS provider once and share it across all units. k8s/helm
# providers are generated per-unit (karpenter, argocd) from the live cluster.
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

# --- Quality gates (hooks) -----------------------------------------------------
# Hooks run PER UNIT, in the unit's generated working directory, AFTER Terragrunt
# runs `terraform init` and BEFORE the terraform command (plan/apply). They act
# as gates so broken config never reaches a real plan/apply.
#
# IMPORTANT: hooks execute in Terragrunt's cache dir (a copy of your module),
# NOT your source tree. So `validate`/scanners below inspect the real executed
# config. Formatting of your actual modules/* source is done at repo root in CI
# (see the workflow) via `terraform fmt -check` + `terragrunt hcl format --check`.
terraform {
  # Hard gate: fail fast if the configuration is internally invalid
  # (undefined vars, type errors, etc.) before running a slow plan.
  before_hook "terraform_validate" {
    commands = ["plan", "apply"]
    execute  = ["bash", "-c", "terraform validate"]
  }

  # Lint. Advisory (`|| true`) until you install tflint:
  #   brew install tflint   (https://github.com/terraform-linters/tflint)
  before_hook "tflint" {
    commands = ["plan", "apply"]
    execute  = ["bash", "-c", "tflint --recursive || true"]
  }

  # Security scan. Advisory (`|| true`) until you install tfsec:
  #   brew install tfsec   (https://github.com/aquasecurity/tfsec)
  before_hook "tfsec" {
    commands = ["plan", "apply"]
    execute  = ["bash", "-c", "tfsec . || true"]
  }
}
