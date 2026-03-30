output "cluster_endpoint" {
  description = "Aurora cluster endpoint"
  value       = aws_rds_cluster.main.endpoint
}

output "cluster_arn" {
  description = "Aurora cluster ARN"
  value       = aws_rds_cluster.main.arn
}

output "cluster_port" {
  description = "Aurora cluster port"
  value       = aws_rds_cluster.main.port
}

output "master_secret_arn" {
  description = "Secrets Manager ARN for master credentials"
  value       = aws_rds_cluster.main.master_user_secret[0].secret_arn
}

output "database_name" {
  description = "Default database name"
  value       = aws_rds_cluster.main.database_name
}

output "pgvector_database_name" {
  description = "pgvector database name"
  value       = "pgvector"
}
