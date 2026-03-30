# ============================================================
# ALB Security Group
# ============================================================

# CloudFront managed prefix list (used when CloudFront is enabled)
data "aws_ec2_managed_prefix_list" "cloudfront" {
  count = var.use_cloudfront ? 1 : 0
  name  = "com.amazonaws.global.cloudfront.origin-facing"
}

resource "aws_security_group" "alb" {
  name   = "dify-alb"
  vpc_id = var.vpc_id

  tags = {
    Name = "dify-alb"
  }
}

# When using CloudFront: allow HTTP from CloudFront prefix list
resource "aws_vpc_security_group_ingress_rule" "alb_from_cloudfront" {
  count             = var.use_cloudfront ? 1 : 0
  security_group_id = aws_security_group.alb.id
  prefix_list_id    = data.aws_ec2_managed_prefix_list.cloudfront[0].id
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

# When NOT using CloudFront: allow from specified CIDRs (or all)
resource "aws_vpc_security_group_ingress_rule" "alb_from_ipv4" {
  for_each = !var.use_cloudfront ? toset(
    length(var.allowed_ipv4_cidrs) > 0 ? var.allowed_ipv4_cidrs : ["0.0.0.0/0"]
  ) : toset([])

  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = each.value
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "alb_from_ipv4_http" {
  for_each = !var.use_cloudfront ? toset(
    length(var.allowed_ipv4_cidrs) > 0 ? var.allowed_ipv4_cidrs : ["0.0.0.0/0"]
  ) : toset([])

  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = each.value
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "alb_from_ipv6" {
  for_each = !var.use_cloudfront && length(var.allowed_ipv6_cidrs) > 0 ? toset(var.allowed_ipv6_cidrs) : toset([])

  security_group_id = aws_security_group.alb.id
  cidr_ipv6         = each.value
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "alb_all" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ============================================================
# ECS Service Security Group
# ============================================================

resource "aws_security_group" "ecs" {
  name   = "dify-ecs"
  vpc_id = var.vpc_id

  tags = {
    Name = "dify-ecs"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ecs_from_alb" {
  security_group_id            = aws_security_group.ecs.id
  referenced_security_group_id = aws_security_group.alb.id
  ip_protocol                  = "-1"
}

resource "aws_vpc_security_group_egress_rule" "ecs_all" {
  security_group_id = aws_security_group.ecs.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ============================================================
# RDS Security Group
# ============================================================

resource "aws_security_group" "rds" {
  name   = "dify-rds"
  vpc_id = var.vpc_id

  tags = {
    Name = "dify-rds"
  }
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_ecs" {
  security_group_id            = aws_security_group.rds.id
  referenced_security_group_id = aws_security_group.ecs.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
}

# ============================================================
# Redis Security Group
# ============================================================

resource "aws_security_group" "redis" {
  name   = "dify-redis"
  vpc_id = var.vpc_id

  tags = {
    Name = "dify-redis"
  }
}

resource "aws_vpc_security_group_ingress_rule" "redis_from_ecs" {
  security_group_id            = aws_security_group.redis.id
  referenced_security_group_id = aws_security_group.ecs.id
  from_port                    = 6379
  to_port                      = 6379
  ip_protocol                  = "tcp"
}
