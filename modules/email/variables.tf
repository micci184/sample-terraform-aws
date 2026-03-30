variable "domain_name" {
  type        = string
  description = "Domain name for SES email identity"
}

variable "hosted_zone_id" {
  type        = string
  description = "Route53 hosted zone ID"
}

variable "aws_region" {
  type        = string
  description = "AWS region"
}
