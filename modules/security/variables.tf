variable "vpc_id" {
  type        = string
  description = "VPC ID"
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

variable "allowed_ipv4_cidrs" {
  type        = list(string)
  description = "IPv4 CIDRs allowed to access ALB directly (when not using CloudFront)"
  default     = []
}

variable "allowed_ipv6_cidrs" {
  type        = list(string)
  description = "IPv6 CIDRs allowed to access ALB directly (when not using CloudFront)"
  default     = []
}
