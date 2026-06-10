output "ec2_public_ip" {
  description = "Public Elastic IP of the EC2 instance"
  value       = aws_eip.app_eip.public_ip
}

output "ec2_instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.app_server.id
}

output "ssh_command" {
  description = "SSH command to connect to the server"
  value       = "ssh -i ~/.ssh/id_rsa ubuntu@${aws_eip.app_eip.public_ip}"
}

output "app_url" {
  description = "Application URL"
  value       = "https://${var.app_subdomain}.${var.domain_name}"
}

output "argocd_url" {
  description = "ArgoCD UI URL"
  value       = "https://argocd.${var.domain_name}"
}

output "acm_certificate_arn" {
  description = "ACM Certificate ARN"
  value       = aws_acm_certificate.app_cert.arn
}

output "route53_nameservers" {
  description = "Route 53 nameservers (update at your domain registrar)"
  value       = aws_route53_zone.primary.name_servers
}
