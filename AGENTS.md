# AGENTS.md — Instructions for AI coding agents

This repository is a **Terragrunt + Terraform** EKS platform. Follow these rules
when editing IaC so the agent harness (Claude, Copilot, Cursor, etc.) stays
consistent with the project's established conventions. These rules exist because
they were decided deliberately — do not "simplify" them away.

## Mental model (read before editing)

- `modules/*` = the **source of truth**: real Terraform code, written once (DRY).
- `environments/<env>/*/terragrunt.hcl` = thin **units**. Each unit only:
  - `include "root" { path = find_in_parent_folders("root.hcl") }` (remote state + quality gates)
  - `include "env" { path = find_in_parent_folders("env.hcl"); expose = true }` (env `locals`, here referenced as `include.env.locals.*`)
  - `terraform { source = "../../../modules/<x>" }` (points at the shared module)
  - `inputs = { ... }` (the env-specific arguments)
  - Units contain **no module code**. dev and prod share the same modules and differ
    only by `inputs`/`locals`. Do not copy a module under `environments/`.
- `root.hcl` = account-global partial: S3 `remote_state` (native locking) + quality-gate hooks.
  `environments/<env>/env.hcl` = env partial: the env-specific `locals` + the AWS
  provider `generate` for that environment.
- **Terragrunt allows only ONE level of includes**, so the two partials are flat
  (neither includes the other) and only leaf units hold `include` blocks. Never
  add an `include` to `root.hcl` or `env.hcl`, and never chain includes 3 deep.

## Hard rules

1. **Never hardcode account IDs, repo URLs, or secrets in committed `.hcl` files.**
   Inject them via `get_env("AWS_ACCOUNT_ID", "")` and
   `get_env("GIT_REPO_URL", "<placeholder>")`. The CI workflow exports these from
   GitHub repo `vars`. If you need a new per-env value, add an env var + `get_env`,
   not a literal.
2. **State uses S3 native locking — no DynamoDB.** `use_lockfile = true` in the
   root `remote_state`. Bucket name = `eks-tf-state-${account_id}` (one bucket per
   AWS account, derived from the same `account_id` used everywhere). Do not add
   DynamoDB lock tables back.
3. **GitOps = one repo, differ by revision.** All environments use the SAME
   `git_repo_url`. They are differentiated by `git_repo_branch` (or a tag) per
   environment — never by a different repository URL. prod must not track `main`
   if dev does; use a protected branch/tag for prod.
4. **Terraform >= 1.10** (required for native S3 locking). Terragrunt version is
   pinned in `.terragrunt-version` — change it there, not hardcoded in CI.
5. **Keep dev minimal.** Deploy `vpc`, `eks`, `security-groups` to dev first.
   Enable `karpenter` (phase 2) and `argocd` (phase 3) only after the current phase
   is understood. `skip = true` units stay disabled until explicitly flipped.

## Quality gates (run before committing)

This repo uses `pre-commit-terraform` (`.pre-commit-config.yaml`). On every commit
it runs `terraform fmt`, `terraform validate`, `tflint`, and `tfsec`.
`terraform-docs` is opt-in — enable the hook once module READMEs have
`BEGIN_TF_DOCS`/`END_TF_DOCS` markers. In CI these are enforced at repo root via
`terraform fmt -recursive -check`, `terragrunt hcl format --check .`, and
`terraform-docs --check`.

> **IMPORTANT — do NOT add `fmt` / `terraform-docs` as a Terragrunt
> `before_hook` / `after_hook`.** Hooks execute in Terragrunt's cache directory
> (a copy of the module), not the `modules/*` source tree, so they would reformat
> or rewrite throwaway files and never touch the real source. Use pre-commit or
> repo-root CI for those. The one correct hook to keep is the per-unit
> `before_hook "terraform_validate"` (it validates the *executed* config, including
> generated providers).

## Workflow conventions

- Use `terragrunt run-all plan/apply --terragrunt-working-dir environments/<env>`.
- `dependency` blocks declare unit ordering and expose outputs — do not remove them.
- After a change: run `terragrunt hcl format`, `terraform fmt -recursive`, and
  confirm `terragrunt list --working-dir environments/<env>` still parses.
- Never commit account IDs, secrets, or unformatted/invalid code.

## Scope of edits

- Fix a bug in a module → edit `modules/<x>/*.tf`; both dev and prod benefit.
- Change an env's behaviour → edit that env's `locals` / unit `inputs`, not the module.
- Bootstrap (`bootstrap/remote-state`) is a one-time per-account step; it is
  intentionally standalone (does not `include` the root) and reads `AWS_ACCOUNT_ID`
  from the environment.

See `HANDOFF.md` (human onboarding/roadmap) and `README.md` for architecture detail.
