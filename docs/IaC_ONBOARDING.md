# IaC Onboarding — Provisioning a New Project from Scratch

**Last reviewed:** 2026-03-11

Step-by-step guide to provision a new GCP project using _XAC Terraform modules. Target: under 30 minutes from blank project to working pipeline.

**See also:** [SECRET_NAMING.md](SECRET_NAMING.md) for secret naming conventions; [../monitoring/runbooks/README.md](../monitoring/runbooks/README.md) for alert runbooks linked from monitoring.

---

## Prerequisites (one-time per GCP project)

1. **Create GCP project**  
   In Cloud Console or via `gcloud`, create a new project and note the project ID.

2. **Enable billing**  
   Link a billing account to the project.

3. **Create Terraform state bucket**  
   State is stored in GCS. Create the bucket before first `terraform apply`:
   ```bash
   gsutil mb -p PROJECT_ID -l REGION gs://PROJECT_ID-terraform-state
   gsutil versioning set on gs://PROJECT_ID-terraform-state
   ```

4. **Enable required APIs**  
   ```bash
   gcloud services enable \
     run.googleapis.com \
     artifactregistry.googleapis.com \
     cloudbuild.googleapis.com \
     secretmanager.googleapis.com \
     vpcaccess.googleapis.com \
     monitoring.googleapis.com \
     iamcredentials.googleapis.com \
     cloudbuild.googleapis.com \
     --project=PROJECT_ID
   ```

---

## Onboarding a new project

1. **Copy the reference project as a template**  
   Copy `_XAC_Config_ContractorScope_/iac/` or the equivalent project dir (e.g. `terraform/projects/contractorscope-ai/`) to a new project path and rename.

2. **Edit `main.tf`**  
   Replace all ContractorScope / contractorscope-ai values with the new project’s identity, GitHub repo, services, artifact registry repo ID, network CIDRs, billing, monitoring, and secrets. Use the same structure; only values change.

3. **Edit `variables.tf` and `terraform.tfvars.example`**  
   Set `project_id`, `region`, `billing_account_id`, `alert_email_addresses`, and any other variables. Copy `terraform.tfvars.example` to `terraform.tfvars` and fill in real values (do not commit `terraform.tfvars`).

4. **Edit `backend.tf`**  
   Set the state bucket to the one you created (e.g. `NEW_PROJECT_ID-terraform-state`).

5. **Add to git and push**  
   Commit the new project directory and push so CI (if configured) can run Terraform.

6. **Run Terraform locally**  
   ```bash
   cd terraform/projects/NEW_PROJECT_NAME
   terraform init
   terraform plan   # review carefully
   terraform apply
   ```

7. **Set secret values**  
   Terraform creates the secrets but does not set their values. Set them manually:
   ```bash
   echo -n "SECRET_VALUE" | gcloud secrets versions add SECRET_ID \
     --data-file=- \
     --project=PROJECT_ID
   ```

8. **Verify outputs**  
   ```bash
   terraform output wif_provider        # use for repo var WIF_PROVIDER
   terraform output ci_service_account  # use for repo var WIF_SERVICE_ACCOUNT
   terraform output service_urls        # Cloud Run URLs
   ```

9. **Add GitHub repo variables**  
   ```bash
   gh variable set WIF_PROVIDER --body "$(terraform output -raw wif_provider)"
   gh variable set WIF_SERVICE_ACCOUNT --body "$(terraform output -raw ci_service_account)"
   gh variable set GOOGLE_CLOUD_PROJECT --body "PROJECT_ID"
   ```

10. **Copy and adapt workflows**  
    Copy `.github/workflows` templates from IAC (e.g. deploy-staging, deploy-production) into the application repo and replace placeholders with the new project’s values.

11. **Verify setup**  
    Run `_XAC/ci/scripts/verify-setup.ps1` (or the project’s equivalent) to confirm Docker, Python, Node, gh, and repo config are correct.

---

## How to apply this in your project

Use this doc as the canonical onboarding checklist. When you add new required steps (e.g. new APIs or secrets), update the list and the "Last reviewed" date. New projects should be able to go from zero to a working deploy pipeline in under 30 minutes by following these steps.
