# Copilot instructions

This repo is a **Terragrunt + Terraform** EKS platform. The authoritative,
complete convention guide is **`AGENTS.md`** at the repo root — read it first and
follow it for every change. The hard rules are summarized below; `AGENTS.md` is
the source of truth (do not let the two drift).

## Non-negotiable rules

1. **Never hardcode account IDs, repo URLs, or secrets** in committed `.hcl`.
   Use `get_env("AWS_ACCOUNT_ID", "")` and `get_env("GIT_REPO_URL", "...")`.
   CI exports these from GitHub repo `vars`.
2. **State = S3 native locking, no DynamoDB.** `use_lockfile = true`.
   Bucket = `eks-tf-state-${account_id}`. Do not add DynamoDB tables.
3. **GitOps = one repo, differ by branch/tag**, not by repo URL.
4. **Modules are DRY:** real code lives in `modules/*`; `environments/<env>/*`
   are thin units (`source` + `inputs`) — never copies of module code.
5. **Terraform >= 1.10**; Terragrunt version pinned in `.terragrunt-version`.

## Quality gates

Use `pre-commit-terraform` (fmt, validate, tflint, tfsec, terraform-docs) before
commits. CI enforces `terraform fmt -check`, `terragrunt hcl format --check`, and
`terraform-docs --check` at repo root. Do **not** put `fmt`/`terraform-docs` in
Terragrunt hooks (they run in the cache dir, not the source). Keep the per-unit
`before_hook "terraform_validate"`.
