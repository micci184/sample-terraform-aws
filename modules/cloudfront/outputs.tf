output "distribution_domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.main.domain_name
}

output "distribution_hosted_zone_id" {
  description = "CloudFront distribution hosted zone ID"
  value       = aws_cloudfront_distribution.main.hosted_zone_id
}

output "distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.main.id
}

output "distribution_url" {
  description = "CloudFront distribution URL"
  value = (
    var.domain_name != null
    ? "https://${var.sub_domain}.${var.domain_name}"
    : "https://${aws_cloudfront_distribution.main.domain_name}"
  )
}
