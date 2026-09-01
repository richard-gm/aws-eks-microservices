# Root Terragrunt partial: shared remote_state (S3 native locking) and quality
# gates, inherited by every leaf unit via `include "root"`.
#
# Deliberately a *partial* — it defines no `inputs` and no `terraform.source`,
# so including it only merges the shared blocks below into each unit.
#
# Per-env values (region, env, CIDRs, cluster settings, ...) live in
# environments/<env>/env.hcl and are pulled into units with a second
# `include "env"`. Terragrunt allows only ONE level of includes, so the
# hierarchy is two flat partials (root.hcl + env.hcl) merged by named
# includes at each leaf — no config includes another config that itself
# includes a third.

locals {
  aws_region = get_env("AWS_REGION", "us-east-1")
  account_id = get_env("AWS_ACCOUNT_ID", "")

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