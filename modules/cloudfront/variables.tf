variable "alb_arn" {
  type        = string
  description = "Internal ALB ARN for VPC origin"
}

variable "alb_dns_name" {
  type        = string
  description = "Internal ALB DNS name"
}

variable "access_log_bucket_domain" {
  type        = string
  description = "S3 bucket domain for CloudFront access logs"
}

variable "web_acl_arn" {
  type        = string
  description = "WAF Web ACL ARN. null = no WAF."
  default     = null
}

variable "certificate_arn" {
  type        = string
  description = "ACM certificate ARN in us-east-1. null = CloudFront default domain."
  default     = null
}

variable "domain_name" {
  type        = string
  description = "Custom domain name. null = no custom domain."
  default     = null
}

variable "sub_domain" {
  type        = string
  description = "Subdomain prefix"
  default     = "dify"
}

variable "aws_region" {
  type        = string
  description = "AWS region"
}
