variable "vpc_id" {
  type        = string
  description = "Import an existing VPC by ID. null = create a new VPC."
  default     = null
}

variable "vpc_isolated" {
  type        = bool
  description = "Create VPC with only isolated subnets (no internet gateway, no NAT)."
  default     = false
}

variable "use_nat_instance" {
  type        = bool
  description = "Use t4g.nano NAT instance instead of NAT Gateway."
  default     = false
}

variable "aws_region" {
  type        = string
  description = "AWS region for deployment."
}

variable "max_azs" {
  type        = number
  description = "Maximum number of availability zones."
  default     = 2
}
