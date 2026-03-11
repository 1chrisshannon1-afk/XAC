# Terraform OPA Policies

These policies run in CI **before** `terraform apply` to enforce platform standards. They evaluate the Terraform plan (JSON) and deny changes that violate the rules.

## Policies

| File | What it enforces |
|------|------------------|
| **cloud-run-health-check.rego** | Every Cloud Run service must define a `liveness_probe` or `startup_probe`. See [HEALTH_CHECK_CONTRACT.md](../docs/HEALTH_CHECK_CONTRACT.md). |
| **no-plain-env-secrets.rego** | Env vars whose names look like secrets (SECRET, KEY, TOKEN, PASSWORD, CREDENTIAL, API_KEY) must not be set as plaintext; they must use Secret Manager (`value_source`). See [SECRET_NAMING.md](../docs/SECRET_NAMING.md). |
| **require-labels.rego** | All created GCP resources (except IAM members/bindings) must have labels: `project`, `company`, `environment`, `managed_by`. |

## Run locally

```bash
# Install OPA: https://www.openpolicyagent.org/docs/latest/#running-opa
# Generate plan JSON (from a project directory):
terraform plan -out=tfplan.binary
terraform show -json tfplan.binary > tfplan.json

# Run all policies (from repo root)
opa eval \
  --input tfplan.json \
  --data terraform/policies/ \
  --format pretty \
  "data.terraform.deny[_]"
```

If the result is empty `[]`, no denials. If it lists messages, fix the Terraform and re-plan.

## Add a new policy

1. Create a new `.rego` file in `terraform/policies/`.
2. Use `package terraform` and define `deny[msg] { ... }` with a clear message.
3. Document it in this README.
4. Ensure CI runs OPA against the plan (see `reusable-terraform.yml`).

## When a policy fires

- **Do not disable the policy** to unblock. Fix the Terraform instead.
- For **cloud-run-health-check**: add a `startup_probe` and/or `liveness_probe` to the Cloud Run service container (path `/health` per HEALTH_CHECK_CONTRACT).
- For **no-plain-env-secrets**: move the secret to Secret Manager and reference it via `value_source.secret_key_ref` in the container env.
- For **require-labels**: add the four labels to the resource (or to a `labels` block that uses `local.standard_labels`).
