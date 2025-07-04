variable "vpc_cidr" {
  type        = string
  description = "The CIDR block for the VPC."
  default     = "10.2.0.0/16"
}

variable "environment" {
  type        = string
  description = "Environment name (development, staging, production)"
  default     = "development"
}

variable "project_name" {
  type        = string
  description = "Name of the project"
  default     = "otel-ecs"
}

variable "grafana_admin_password" {
  type        = string
  description = "Admin password for Grafana"
  default     = "admin"
  sensitive   = true
}
