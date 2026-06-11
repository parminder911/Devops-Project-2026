output "alb_dns_name" {
  description = "The public DNS name of the Application Load Balancer"
  value       = aws_lb.app_alb.dns_name
}

output "alb_security_group_id" {
  description = "The ID of the ALB Security Group to allow inbound access on EC2"
  value       = aws_security_group.alb_sg.id
}

output "route53_records" {
  description = "Configured DNS names"
  value       = [
    aws_route53_record.root.name,
    aws_route53_record.www.name
  ]
}
