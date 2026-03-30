variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for the DB subnet group"
}

variable "rds_security_group_id" {
  type        = string
  description = "Security group ID for RDS"
}

variable "enable_aurora_scales_to_zero" {
  type        = bool
  description = "Allow Aurora Serverless v2 to scale to 0 ACU"
  default     = false
}

variable "aws_region" {
  type        = string
  description = "AWS region"
}
