variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Public subnet IDs"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs"
}

variable "alb_security_group_id" {
  type        = string
  description = "Security group ID for ALB"
}

variable "access_log_bucket_id" {
  type        = string
  description = "S3 bucket for access logs"
}

variable "use_cloudfront" {
  type        = bool
  description = "Whether CloudFront is deployed in front of ALB"
  default     = true
}

variable "internal_alb" {
  type        = bool
  description = "Whether ALB is deployed in private subnets"
  default     = false
}

variable "certificate_arn" {
  type        = string
  description = "ACM certificate ARN for HTTPS listener. null = HTTP only."
  default     = null
}
