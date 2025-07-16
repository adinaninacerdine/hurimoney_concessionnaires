variable "aws_region" {
  description = "The AWS region to create resources in."
  default     = "eu-north-1"
}

variable "documentdb_password" {
  description = "DocumentDB master password"
  type        = string
  sensitive   = true
}

variable "odoo_api_url" {
  description = "Odoo API URL"
  type        = string
}

variable "odoo_api_key" {
  description = "Odoo API key"
  type        = string
  sensitive   = true
}