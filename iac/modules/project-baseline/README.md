# project-baseline

Top-level module that provisions a full GCP project environment: WIF, Artifact Registry, optional VPC, secrets, Cloud Run services, Cloud Build trigger, budget alerts, and monitoring per service.

## Inputs

See variables.tf. Grouped: Identity, GitHub, Services, Artifact Registry, Network, Cost, Monitoring, Secrets, Cloud Build.

## Outputs

| Name | Description |
|------|-------------|
| wif_provider | WIF provider name (for GitHub var) |
| ci_service_account | CI deployer SA email (for GitHub var) |
| artifact_registry_url | Docker repo URL |
| service_urls | Map of service name → URL |
| vpc_connector_name | VPC connector name (if VPC enabled) |

## Example

See `terraform/projects/contractorscope-ai/main.tf`.
