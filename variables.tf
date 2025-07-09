variable "aws_region" {
  description = "The AWS region to deploy to."
  default     = "us-east-1"
}

variable "instance_type" {
  description = "The type of EC2 instance to use."
  default     = "t2.micro"
}

variable "ssh_key_name" {
  description = "The name of your SSH key pair in AWS."
  type        = string
}
