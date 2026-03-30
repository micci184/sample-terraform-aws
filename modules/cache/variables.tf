variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for the ElastiCache subnet group"
}

variable "redis_security_group_id" {
  type        = string
  description = "Security group ID for ElastiCache"
}

variable "is_redis_multi_az" {
  type        = bool
  description = "Deploy across multiple AZs with automatic failover"
  default     = true
}
