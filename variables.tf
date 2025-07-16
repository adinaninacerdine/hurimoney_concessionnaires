variable "aws_region" {
  description = "The AWS region to create resources in."
  default     = "us-east-1"
}

variable "mongodb_uri" {
  description = "MongoDB connection URI"
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