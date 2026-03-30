output "storage_bucket_id" {
  description = "Storage bucket name"
  value       = aws_s3_bucket.storage.id
}

output "storage_bucket_arn" {
  description = "Storage bucket ARN"
  value       = aws_s3_bucket.storage.arn
}

output "access_log_bucket_id" {
  description = "Access log bucket name"
  value       = aws_s3_bucket.access_log.id
}

output "access_log_bucket_domain" {
  description = "Access log bucket domain name (for CloudFront/ALB logging)"
  value       = aws_s3_bucket.access_log.bucket_domain_name
}
