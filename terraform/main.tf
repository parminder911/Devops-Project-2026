# ─── Terraform Provider & Backend ────────────────────────────────────────────
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state in S3 — uncomment after creating the bucket manually first
  # backend "s3" {
  #   bucket  = "hudocafe-terraform-state"
  #   key     = "devops-project/terraform.tfstate"
  #   region  = "ap-south-1"
  #   encrypt = true
  # }
}

provider "aws" {
  region = var.aws_region
}

# ─── Data: Latest Ubuntu 22.04 AMI ───────────────────────────────────────────
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ─── Key Pair ─────────────────────────────────────────────────────────────────
resource "aws_key_pair" "devops" {
  key_name   = "${var.project_name}-key"
  public_key = file(var.public_key_path)

  # If key pair already exists, import it:  bash scripts/terraform-import.sh
  lifecycle {
    ignore_changes = [public_key, tags]
  }

  tags = local.common_tags
}

# ─── EC2 Instance ─────────────────────────────────────────────────────────────
resource "aws_instance" "app_server" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.devops.key_name
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.app_sg.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  # Bootstrap: install Docker, k3s, ArgoCD
  user_data = file("${path.module}/user_data.sh")

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-server"
    Role = "app-server"
  })
}

# ─── Elastic IP ───────────────────────────────────────────────────────────────
resource "aws_eip" "app_eip" {
  instance = aws_instance.app_server.id
  domain   = "vpc"

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-eip"
  })

  depends_on = [aws_internet_gateway.igw]
}

# ─── Locals ───────────────────────────────────────────────────────────────────
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Owner       = "DevOps"
  }
}
