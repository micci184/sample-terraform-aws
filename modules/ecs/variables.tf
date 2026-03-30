variable "aws_region" {
  type        = string
  description = "AWS region"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for ECS services"
}

variable "ecs_security_group_id" {
  type        = string
  description = "Security group ID for ECS services"
}

# ---- Storage ----

variable "storage_bucket_id" {
  type        = string
  description = "S3 storage bucket name"
}

variable "storage_bucket_arn" {
  type        = string
  description = "S3 storage bucket ARN"
}

# ---- Database ----

variable "db_secret_arn" {
  type        = string
  description = "Secrets Manager ARN for Aurora master credentials"
}

variable "db_database_name" {
  type        = string
  description = "Default database name"
}

variable "pgvector_database_name" {
  type        = string
  description = "pgvector database name"
}

# ---- Cache ----

variable "redis_endpoint" {
  type        = string
  description = "ElastiCache primary endpoint"
}

variable "redis_port" {
  type        = number
  description = "ElastiCache port"
  default     = 6379
}

variable "redis_auth_secret_arn" {
  type        = string
  description = "Secrets Manager ARN for Redis auth token"
}

variable "broker_url_parameter_arn" {
  type        = string
  description = "SSM Parameter ARN for Celery broker URL"
}

# ---- Container images ----

variable "dify_image_tag" {
  type        = string
  description = "Image tag for dify-api and dify-web"
  default     = "1.11.4"
}

variable "dify_sandbox_image_tag" {
  type        = string
  description = "Image tag for dify-sandbox"
  default     = "latest"
}

variable "dify_plugin_daemon_image_tag" {
  type        = string
  description = "Image tag for dify-plugin-daemon"
  default     = "0.5.2-local"
}

variable "custom_ecr_repository_name" {
  type        = string
  description = "ECR repository name for custom images. null = Docker Hub."
  default     = null
}

variable "sandbox_init_image_uri" {
  type        = string
  description = "ECR image URI for sandbox init container"
}

variable "external_kb_image_uri" {
  type        = string
  description = "ECR image URI for external knowledge base API container"
}

# ---- Feature flags ----

variable "allow_any_syscalls" {
  type        = bool
  description = "Allow all syscalls in sandbox"
  default     = false
}

variable "use_fargate_spot" {
  type        = bool
  description = "Use Fargate Spot capacity"
  default     = false
}

# ---- ALB ----

variable "alb_url" {
  type        = string
  description = "ALB URL for service endpoints"
}

variable "api_target_group_arn" {
  type        = string
  description = "Target group ARN for API service"
}

variable "extension_target_group_arn" {
  type        = string
  description = "Target group ARN for plugin daemon (extension)"
}

variable "web_target_group_arn" {
  type        = string
  description = "Target group ARN for web service"
}

# ---- Email (optional) ----

variable "email_smtp_secret_arn" {
  type        = string
  description = "Secrets Manager ARN for SMTP credentials"
  default     = null
}

variable "email_smtp_server" {
  type        = string
  description = "SMTP server address"
  default     = null
}

variable "email_smtp_port" {
  type        = string
  description = "SMTP server port"
  default     = "465"
}

variable "email_domain_name" {
  type        = string
  description = "Email domain for MAIL_DEFAULT_SEND_FROM"
  default     = null
}
