# ─── ACM Certificate ──────────────────────────────────────────────────────────
# Covers both root domain and wildcard subdomains
resource "aws_acm_certificate" "app_cert" {
  domain_name               = var.domain_name
  subject_alternative_names = [
    "*.${var.domain_name}",          # *.hudocafe.com
    "${var.app_subdomain}.${var.domain_name}",  # api.hudocafe.com
    "argocd.${var.domain_name}",     # argocd.hudocafe.com
  ]
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.common_tags, { Name = "${var.project_name}-cert" })
}

# ─── DNS Validation Records ───────────────────────────────────────────────────
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.app_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = aws_route53_zone.primary.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]
}

# ─── Certificate Validation Wait ─────────────────────────────────────────────
resource "aws_acm_certificate_validation" "app_cert" {
  certificate_arn         = aws_acm_certificate.app_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}
