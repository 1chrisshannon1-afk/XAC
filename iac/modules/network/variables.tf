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

variable "region" {
  type    = string
  default = "us-central1"
}

variable "vpc_name" {
  type    = string
  default = "main"
}

variable "subnet_cidr" {
  type    = string
  default = "10.0.0.0/24"
}

variable "connector_cidr" {
  type        = string
  default     = "10.8.0.0/28"
  description = "Must be /28, must not overlap subnet_cidr"
}

variable "connector_min_instances" {
  type    = number
  default = 2
}

variable "connector_max_instances" {
  type    = number
  default = 3
}

variable "enable_private_google_access" {
  type    = bool
  default = true
}

variable "enable_cloud_nat" {
  type    = bool
  default = true
}
