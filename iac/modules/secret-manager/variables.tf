variable "project_id" {
  type = string
}

variable "project_name" {
  type = string
}

variable "company" {
  type = string
}

variable "environment" {
  type = string
}

variable "secret_id" {
  type        = string
  description = "Secret name. Convention: {env}-{project}-{name}. e.g. staging-csa-backend-firebase-api-key"
}

variable "accessor_members" {
  type        = list(string)
  description = "IAM members granted secretAccessor role"
}

variable "automatic_replication" {
  type        = bool
  default     = true
  description = "Reserved for future use: when false, use user_managed replication. Currently replication is always auto {}."
}
