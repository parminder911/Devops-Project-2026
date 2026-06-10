# ─── ACM Certificate ──────────────────────────────────────────────────────────
# We use the EXISTING certificate you already have in AWS:
# ARN: arn:aws:acm:ap-south-1:652942059153:certificate/a7ff8bf3-39f9-41fd-99e8-4968443c9c33
#
# Using a data source reads the existing cert — does NOT create a new one.
data "aws_acm_certificate" "app_cert" {
  domain   = var.domain_name       # hudocafe.com
  statuses = ["ISSUED"]            # Only returns if cert is already validated
}
