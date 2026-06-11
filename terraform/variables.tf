variable "aws_region" {
  description = "AWS region where resources are deployed"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project name prefix"
  type        = string
  default     = "hudocafe"
}

variable "environment" {
  description = "Deployment environment name"
  type        = string
  default     = "production"
}

variable "domain_name" {
  description = "Root domain name for Route 53"
  type        = string
  default     = "hudocafe.com"
}

variable "existing_instance_id" {
  description = "The Instance ID of the manually launched EC2 server (e.g., i-0123456789abcdef0)"
  type        = string
}
