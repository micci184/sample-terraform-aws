output "smtp_secret_arn" {
  description = "Secrets Manager ARN for SMTP credentials"
  value       = aws_secretsmanager_secret.smtp.arn
}

output "smtp_server" {
  description = "SMTP server address"
  value       = "email-smtp.${var.aws_region}.amazonaws.com"
}

output "smtp_port" {
  description = "SMTP server port"
  value       = "465"
}

output "domain_name" {
  description = "Email domain name"
  value       = var.domain_name
}
