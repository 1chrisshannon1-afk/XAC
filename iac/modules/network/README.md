# network

Creates VPC, subnets, and Serverless VPC Access connector for Cloud Run. Shared across all services in a project.

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| project_id | string | - | GCP project ID |
| project_name | string | - | Project name (for labels) |
| company | string | - | Company name (for labels) |
| environment | string | - | staging or production |
| region | string | "us-central1" | Region |
| vpc_name | string | "main" | VPC name |
| subnet_cidr | string | "10.0.0.0/24" | Subnet CIDR |
| connector_cidr | string | "10.8.0.0/28" | Connector /28 CIDR (must not overlap subnet) |
| connector_min_instances | number | 2 | Connector min instances |
| connector_max_instances | number | 3 | Connector max instances |
| enable_private_google_access | bool | true | Private Google access on subnet |
| enable_cloud_nat | bool | true | Create Cloud NAT |

## Outputs

| Name | Description |
|------|-------------|
| vpc_id | VPC resource ID |
| vpc_name | VPC name |
| subnet_id | Subnet resource ID |
| connector_id | VPC Access connector ID |
| connector_name | Connector name (use in Cloud Run vpc_connector) |

## Example

```hcl
module "network" {
  source = "../../modules/network"

  project_id   = "my-project"
  project_name = "my-project"
  company      = "mycompany"
  environment  = "staging"
  region       = "us-central1"
}
```
