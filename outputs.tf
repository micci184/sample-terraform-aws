output "dify_url" {
  description = "URL to access Dify"
  value       = local.dify_url
}

output "console_connect_command" {
  description = "ECS Exec command to connect to API container"
  value       = <<-EOT
    aws ecs execute-command \
      --region ${var.aws_region} \
      --cluster ${module.ecs.cluster_name} \
      --container dify-api \
      --interactive \
      --command "bash" \
      --task $(aws ecs list-tasks --region ${var.aws_region} --cluster ${module.ecs.cluster_name} --service-name ${module.ecs.api_service_name} --desired-status RUNNING --query 'taskArns[0]' --output text)
  EOT
}

output "storage_bucket_name" {
  description = "S3 storage bucket name"
  value       = module.storage.storage_bucket_id
}

output "database_secret_arn" {
  description = "Secrets Manager ARN for database credentials"
  value       = module.database.master_secret_arn
}
