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
  value       = "ssh -i /root/.ssh/id_rsa ubuntu@${aws_eip.app_eip.public_ip}"
}

output "app_url" {
  description = "Application URL"
  value       = "https://${var.app_subdomain}.${var.domain_name}"
}

output "argocd_url" {
  description = "ArgoCD UI URL (also accessible via CLI)"
  value       = "http://${aws_eip.app_eip.public_ip}:30080"
}

output "acm_certificate_arn" {
  description = "Existing ACM Certificate ARN"
  value       = data.aws_acm_certificate.app_cert.arn
}

output "ecr_repository_uri" {
  description = "ECR repository URI for pushing Docker images"
  value       = aws_ecr_repository.app.repository_url
}

output "s3_backup_bucket" {
  description = "S3 bucket name for PostgreSQL backups"
  value       = aws_s3_bucket.backups.bucket
}

output "route53_nameservers" {
  description = "Route 53 nameservers — update these at your domain registrar"
  value       = aws_route53_zone.primary.name_servers
}

output "setup_instructions" {
  description = "Next steps after terraform apply"
  value = <<-EOT
  =============================================
  NEXT STEPS:
  1. SSH: ssh -i /root/.ssh/id_rsa ubuntu@${aws_eip.app_eip.public_ip}
  2. Wait ~5 min for bootstrap, then: sudo tail -f /var/log/user-data.log
  3. Check k3s: kubectl get nodes
  4. Check ArgoCD: kubectl get pods -n argocd
  5. Update nameservers at your registrar: ${join(", ", aws_route53_zone.primary.name_servers)}
  ECR URI: ${aws_ecr_repository.app.repository_url}
  =============================================
  EOT
}
