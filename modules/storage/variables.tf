variable "name_prefix" {
  type        = string
  description = "Prefix for S3 bucket names."
  default     = "dify"
}

variable "aws_region" {
  type        = string
  description = "AWS region for deployment."
}
