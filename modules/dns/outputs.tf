output "hosted_zone_id" {
  description = "Route53 hosted zone ID"
  value       = data.aws_route53_zone.main.zone_id
}

output "fqdn" {
  description = "Fully qualified domain name for Dify"
  value       = "${var.sub_domain}.${var.domain_name}"
}

output "certificate_arn" {
  description = "ACM certificate ARN (main region)"
  value       = aws_acm_certificate.main.arn
}

output "cloudfront_certificate_arn" {
  description = "ACM certificate ARN in us-east-1 (for CloudFront)"
  value       = var.use_cloudfront ? aws_acm_certificate.cloudfront[0].arn : null
}
