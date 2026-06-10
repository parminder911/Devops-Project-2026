variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project name used as prefix for all resources"
  type        = string
  default     = "hudocafe"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "production"
}

variable "instance_type" {
  description = "EC2 instance type (t3.medium recommended for k3s + all services)"
  type        = string
  default     = "t3.medium"
}

variable "public_key_path" {
  description = "Path to your SSH public key on local machine"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "domain_name" {
  description = "Your root domain name (must already be registered in Route 53)"
  type        = string
  default     = "hudocafe.com"
}

variable "app_subdomain" {
  description = "Subdomain for the application (api.hudocafe.com)"
  type        = string
  default     = "api"
}

variable "allowed_ssh_cidr" {
  description = "Your IP CIDR for SSH access — restrict to your IP for security"
  type        = string
  default     = "0.0.0.0/0"  # Change to YOUR_IP/32 in production!
}
