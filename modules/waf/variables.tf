variable "allowed_ipv4_cidrs" {
  type        = list(string)
  description = "IPv4 CIDRs to allow"
  default     = []
}

variable "allowed_ipv6_cidrs" {
  type        = list(string)
  description = "IPv6 CIDRs to allow"
  default     = []
}

variable "name_prefix" {
  type        = string
  description = "Prefix for WAF resource names"
  default     = "dify"
}
