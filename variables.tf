variable "aws_region" {
  type        = string
  description = "AWS region for deployment"
  default     = "us-west-2"
}

variable "allowed_ipv4_cidrs" {
  type        = list(string)
  description = "IPv4 CIDR blocks allowed to access the app. Empty list allows all."
  default     = []
}

variable "allowed_ipv6_cidrs" {
  type        = list(string)
  description = "IPv6 CIDR blocks allowed to access the app. Empty list allows all."
  default     = []
}

# ---- VPC ----

variable "vpc_id" {
  type        = string
  description = "Import an existing VPC instead of creating a new one. Must have public and private subnets."
  default     = null
}

variable "vpc_isolated" {
  type        = bool
  description = "Create VPC with only isolated subnets (no internet gateway, no NAT). Ignored when vpc_id is set."
  default     = false
}

variable "use_nat_instance" {
  type        = bool
  description = "Use t4g.nano NAT instance instead of NAT Gateway (~$3/month vs ~$33/month). Ignored when vpc_id is set."
  default     = false
}

# ---- Domain ----

variable "domain_name" {
  type        = string
  description = "Route53 hosted zone domain name. Enables TLS and custom domain."
  default     = null
}

variable "sub_domain" {
  type        = string
  description = "Subdomain prefix. Dify is accessible at https://<sub_domain>.<domain_name>."
  default     = "dify"
}

# ---- Database ----

variable "enable_aurora_scales_to_zero" {
  type        = bool
  description = "Allow Aurora Serverless v2 to scale to 0 ACU (with ~10s cold start)."
  default     = false
}

# ---- Cache ----

variable "is_redis_multi_az" {
  type        = bool
  description = "Deploy ElastiCache Valkey across multiple AZs with automatic failover."
  default     = true
}

# ---- Compute ----

variable "use_fargate_spot" {
  type        = bool
  description = "Use Fargate Spot capacity (may be interrupted). Recommended for non-critical use."
  default     = false
}

variable "dify_image_tag" {
  type        = string
  description = "Image tag for dify-api and dify-web containers."
  default     = "1.11.4"
}

variable "dify_sandbox_image_tag" {
  type        = string
  description = "Image tag for dify-sandbox container."
  default     = "latest"
}

variable "dify_plugin_daemon_image_tag" {
  type        = string
  description = "Image tag for dify-plugin-daemon container."
  default     = "0.5.2-local"
}

variable "allow_any_syscalls" {
  type        = bool
  description = "Allow all syscalls in sandbox. DANGEROUS — only enable if sandbox code is trusted."
  default     = false
}

# ---- Load Balancing ----

variable "use_cloudfront" {
  type        = bool
  description = "Deploy CloudFront in front of internal ALB. Recommended when no custom domain is set."
  default     = true
}

variable "internal_alb" {
  type        = bool
  description = "Deploy ALB in private subnets (not internet-facing). Cannot be used with use_cloudfront."
  default     = false

  validation {
    condition     = !(var.internal_alb && var.use_cloudfront)
    error_message = "internal_alb cannot be true when use_cloudfront is true."
  }
}

# ---- ECR ----

variable "custom_ecr_repository_name" {
  type        = string
  description = "Pull Dify images from this private ECR repository instead of Docker Hub."
  default     = null
}

# ---- Email ----

variable "setup_email" {
  type        = bool
  description = "Configure SES and SMTP credentials using domain_name."
  default     = false

  validation {
    condition     = !var.setup_email || var.domain_name != null
    error_message = "setup_email requires domain_name to be set."
  }
}

# ---- Additional Environment Variables ----

variable "additional_plain_env_vars" {
  type = list(object({
    key     = string
    value   = string
    targets = optional(list(string))
  }))
  description = "Additional plain-text environment variables. targets: web, api, worker, sandbox."
  default     = []
}

variable "additional_ssm_env_vars" {
  type = list(object({
    key            = string
    parameter_name = string
    targets        = optional(list(string))
  }))
  description = "Additional environment variables from SSM Parameter Store."
  default     = []
}

variable "additional_secret_env_vars" {
  type = list(object({
    key         = string
    secret_name = string
    field       = optional(string)
    targets     = optional(list(string))
  }))
  description = "Additional environment variables from Secrets Manager."
  default     = []
}
