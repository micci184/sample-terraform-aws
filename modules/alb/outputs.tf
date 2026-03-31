output "alb_arn" {
  description = "ALB ARN"
  value       = aws_lb.main.arn
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "ALB hosted zone ID"
  value       = aws_lb.main.zone_id
}

output "alb_url" {
  description = "ALB URL (http or https)"
  value       = var.certificate_arn != null ? "https://${aws_lb.main.dns_name}" : "http://${aws_lb.main.dns_name}"
}

output "api_target_group_arn" {
  description = "API target group ARN"
  value       = aws_lb_target_group.api.arn
}

output "extension_target_group_arn" {
  description = "Extension (plugin daemon) target group ARN"
  value       = aws_lb_target_group.extension.arn
}

output "web_target_group_arn" {
  description = "Web target group ARN"
  value       = aws_lb_target_group.web.arn
}
