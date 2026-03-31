output "vpc_id" {
  description = "VPC ID"
  value       = local.vpc_id
}

output "vpc_cidr_block" {
  description = "VPC CIDR block"
  value       = local.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = local.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs (private with egress or isolated)"
  value       = local.private_subnet_ids
}

output "availability_zones" {
  description = "Availability zones used"
  value       = local.azs
}
