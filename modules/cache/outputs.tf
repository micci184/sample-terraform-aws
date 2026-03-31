output "primary_endpoint" {
  description = "Primary endpoint address"
  value       = aws_elasticache_replication_group.main.primary_endpoint_address
}

output "port" {
  description = "Redis port"
  value       = 6379
}

output "auth_token_secret_arn" {
  description = "Secrets Manager ARN for the auth token"
  value       = aws_secretsmanager_secret.redis_auth.arn
}

output "broker_url_parameter_arn" {
  description = "SSM Parameter ARN for Celery broker URL"
  value       = aws_ssm_parameter.broker_url.arn
}

output "broker_url_parameter_name" {
  description = "SSM Parameter name for Celery broker URL"
  value       = aws_ssm_parameter.broker_url.name
}
