terraform {
  backend "gcs" {
    bucket = "{{GCP_PROJECT}}-terraform-state"
    prefix = "terraform/state"
  }
}
