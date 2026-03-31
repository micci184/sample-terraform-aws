variable "domain_name" {
  type        = string
  description = "Route53 hosted zone domain name"
}

variable "sub_domain" {
  type        = string
  description = "Subdomain prefix"
  default     = "dify"
}

variable "use_cloudfront" {
  type        = bool
  description = "Whether CloudFront is used (determines which cert to create)"
  default     = true
}

# Target for DNS record (CloudFront or ALB)
variable "target_dns_name" {
  type        = string
  description = "DNS name of CloudFront distribution or ALB"
}

variable "target_zone_id" {
  type        = string
  description = "Hosted zone ID of CloudFront distribution or ALB"
}
