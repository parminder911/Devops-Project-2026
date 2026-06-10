# ─── Route 53 Hosted Zone ─────────────────────────────────────────────────────
# Creates a new hosted zone for hudocafe.com
# After terraform apply → update nameservers at your domain registrar
resource "aws_route53_zone" "primary" {
  name = var.domain_name

  tags = merge(local.common_tags, { Name = "${var.project_name}-zone" })
}

# ─── A Record → EC2 Elastic IP ───────────────────────────────────────────────
resource "aws_route53_record" "app_root" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = var.domain_name
  type    = "A"
  ttl     = 300
  records = [aws_eip.app_eip.public_ip]
}

resource "aws_route53_record" "app_www" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"
  ttl     = 300
  records = [aws_eip.app_eip.public_ip]
}

resource "aws_route53_record" "app_api" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "${var.app_subdomain}.${var.domain_name}"
  type    = "A"
  ttl     = 300
  records = [aws_eip.app_eip.public_ip]
}

resource "aws_route53_record" "argocd" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "argocd.${var.domain_name}"
  type    = "A"
  ttl     = 300
  records = [aws_eip.app_eip.public_ip]
}
