# aws-monitoring-scripts

Python monitoring scripts that run inside a single AWS Lambda and push metrics
into an existing Grafana/Prometheus stack (the
[grafana-stack-aws](https://github.com/richard-gm/grafana-stack-aws) repo) via
its **Prometheus Pushgateway**.

One Lambda, many triggers:

```
                         ┌─────────────────────────────┐
  EventBridge (cron) ───▶│                             │   download
  EventBridge (cron) ───▶│   monitoring Lambda (VPC)   │──▶ s3://scripts/<name>.py
  EventBridge (cron) ───▶│                             │        │
                         └──────────────┬──────────────┘        │ run as subprocess
                                        │                       ▼
                                        │              script uses monitoring_sdk
                                        │              (Lambda LAYER) to push
                                        └────────────▶ Prometheus Pushgateway :9091
                                                          (scraped by Prometheus → Grafana)
```

* **Single Lambda** dispatches by the `script` key in the EventBridge event.
* **Multiple EventBridge schedule rules** (cron/rate) each invoke the same
  Lambda with a different `{ "script": "...", "job": "..." }` payload.
* **Scripts live in `monitoring-scripts/`** and are uploaded to S3 by the GitHub
  Action on merge to `develop`/`main`. Adding a monitor = add a file + add one
  entry to `monitoring_jobs` — **no Lambda redeploy**.
* **Shared `monitoring_sdk` layer** (stdlib-only Prometheus Pushgateway client)
  is available to every script.

## Repository layout

```
aws-monitoring-scripts/
├── .github/workflows/terraform.yml   # OIDC → terraform apply → sync scripts to S3
├── environments/
│   ├── nonprod/                      # terraform.tfvars with your account/VPC values
│   └── prod/
├── modules/
│   ├── github-oidc/                  # GitHub OIDC IAM role (reuses grafana-stack provider)
│   └── monitoring-lambda/            # Lambda + layer + S3 bucket + EventBridge rules
├── src/
│   ├── lambda_handler.py             # dispatcher
│   └── monitoring_sdk/              # shared layer package
└── monitoring-scripts/              # <-- your monitors; uploaded to S3 by CI
    ├── check_rds_snapshots.py
    └── check_s3_lifecycle.py
```

## Wiring to the grafana-stack-aws deployment

Fill these in `environments/<env>/terraform.tfvars` using outputs from the
grafana-stack-aws deployment:

| tfvars key                     | Source (grafana-stack-aws output)                              |
|--------------------------------|----------------------------------------------------------------|
| `vpc_id`                       | `module.vpc.vpc_id`                                             |
| `private_subnet_ids`           | `module.vpc.private_subnet_ids`                                |
| `pushgateway_security_group_id`| `module.ecs.ecs_security_group_id` (SG protecting Pushgateway) |
| `pushgateway_url`              | `http://pushgateway.<service_discovery_namespace_name>:9091`   |

> The module creates its **own** Lambda security group and adds an ingress rule
> to the Pushgateway SG (`pushgateway_security_group_id`) allowing `:9091` from
> the Lambda SG. So you no longer reuse the ECS SG directly for the Lambda — you
> just point `pushgateway_security_group_id` at it. The namespace name is the
> `service_discovery_namespace_name` output of the `ecs` module.
>
> **Network prerequisite:** the private subnets must have a route to the internet
> (NAT gateway) — the Lambda downloads scripts from S3 and calls AWS APIs, both
> over the public endpoints. The grafana-stack-aws VPC has a NAT gateway.

## Adding a new monitor

1. Drop a script in `monitoring-scripts/`, e.g. `check_elb_health.py`.
   It can `import boto3` (Lambda runtime) and `from monitoring_sdk import Pushgateway, Metric`.
2. Add an entry to `monitoring_jobs` in `environments/<env>/terraform.tfvars`:

   ```hcl
   monitoring_jobs = [
     {
       name        = "elb-health"
       script      = "check_elb_health"
       job         = "elb-health"
       schedule    = "cron(0/15 * * * ? *)"  # every 15 min
       description = "ALB target health"
     },
   ]
   ```
3. Merge to `develop` (nonprod) or `main` (prod). Terraform creates the
   EventBridge rule and the Action uploads the new script to S3.

## Writing a script

```python
import os
from monitoring_sdk import Pushgateway, Metric

def main():
    g = Metric("my_gauge", "gauge", "example")
    g.add(42, {"label": "a"})
    Pushgateway(
        os.environ["PUSHGATEWAY_URL"],
        job=os.environ.get("JOB", "my-job"),
    ).push([g])

if __name__ == "__main__":
    main()
```

Environment provided to every script: `PUSHGATEWAY_URL`, `JOB`, `SCRIPT`,
plus the normal Lambda/AWS env (`AWS_REGION`, `AWS_DEFAULT_REGION`, …).

## IAM for the monitors

The Lambda execution role gets a default **read-only** policy
(`lambda_policy_json` in `modules/monitoring-lambda/variables.tf`) covering
common `Describe*`/`List*`/`Get*` actions. If a monitor needs a permission not in
the default (e.g. `secretsmanager:GetSecretValue`, `kms:Decrypt`), override
`lambda_policy_json` in `environments/<env>/terraform.tfvars`:

```hcl
lambda_policy_json = jsonencode({
  Version = "2012-10-17"
  Statement = [{
    Effect   = "Allow"
    Action   = ["rds:Describe*", "secretsmanager:GetSecretValue"]
    Resource = "*"
  }]
})
```

## Heartbeat, up-signal & alarms

To avoid the classic "last good value looks healthy" trap, the handler pushes two
metrics on **every** run (success or failure), even when the script itself
produces nothing:

* `monitoring_run_status{script,job,status}` — `1` if the run succeeded, `0` otherwise.
* `monitoring_run_timestamp_seconds{script,job}` — unix time of the last run.

Build a Grafana panel that alerts when `monitoring_run_status == 0`, or when
`monitoring_run_timestamp_seconds` is older than your longest schedule.

Three CloudWatch alarms are created per environment (in
`modules/monitoring-lambda/alarms.tf`):

* `…-monitoring-errors` — Lambda `Errors > 0`
* `…-monitoring-throttles` — Lambda `Throttles > 0`
* `…-monitoring-no-invocations` — `Invocations == 0` over `missed_run_period`
  (default 24h), treating missing data as **breaching** (catches a dead
  EventBridge schedule)

Set `alarm_actions = ["arn:aws:sns:…:my-topic"]` in tfvars to route alarms to SNS.

## Grafana-side requirements (must verify in the grafana-stack-aws account)

These live **outside this repo** (the Prometheus config is stored in an S3 bucket
in the grafana deployment); without them no metrics appear:

1. Prometheus must have a scrape job targeting the Pushgateway
   (`pushgateway.<namespace>:9091`).
2. That scrape job must set **`honor_labels: true`**, otherwise your per-monitor
   `job` labels are overwritten by the pushgateway scrape job name.
3. The GitHub OIDC provider from grafana-stack-aws must already exist (this repo
   references it via a data source). Deploy grafana-stack-aws first.

## CI/CD

The GitHub Action (`terraform.yml`) mirrors the grafana-stack-aws workflow:

* `pull_request` → `terraform plan`
* `push` to `develop`/`main` → `terraform apply` (env from branch) **then**
  `aws s3 sync monitoring-scripts/ s3://monitoring-scripts-<account>-<env>/`

Required GitHub repo variables:

* `AWS_ACCOUNT_ID_NONPROD`
* `AWS_ACCOUNT_ID_PROD`

The OIDC role `aws-monitoring-github-actions-<env>` is created by Terraform.
It trusts the **existing** GitHub OIDC provider created by grafana-stack-aws.

## Bootstrap

```bash
# one-time: create the Terraform state bucket (versioned)
aws s3 mb s3://aws-monitoring-terraform-state-nonprod --region us-east-1
aws s3api put-bucket-versioning --bucket aws-monitoring-terraform-state-nonprod \
  --versioning-configuration Status=Enabled

cd environments/nonprod
terraform init
terraform apply
```
