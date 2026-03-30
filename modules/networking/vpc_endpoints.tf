# VPC Endpoints for isolated mode (no internet access)
# Provides connectivity to AWS services without NAT/IGW

locals {
  interface_endpoints = local.is_isolated ? toset([
    "com.amazonaws.${var.aws_region}.ecr.api",
    "com.amazonaws.${var.aws_region}.ecr.dkr",
    "com.amazonaws.${var.aws_region}.secretsmanager",
    "com.amazonaws.${var.aws_region}.ssm",
    "com.amazonaws.${var.aws_region}.logs",
    "com.amazonaws.${var.aws_region}.bedrock-runtime",
    "com.amazonaws.${var.aws_region}.bedrock-agent-runtime",
    "com.amazonaws.${var.aws_region}.ssmmessages",
  ]) : toset([])
}

resource "aws_security_group" "vpc_endpoints" {
  count  = local.is_isolated ? 1 : 0
  name   = "dify-vpc-endpoints"
  vpc_id = aws_vpc.main[0].id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main[0].cidr_block]
  }

  tags = {
    Name = "dify-vpc-endpoints"
  }
}

resource "aws_vpc_endpoint" "interface" {
  for_each = local.interface_endpoints

  vpc_id              = aws_vpc.main[0].id
  service_name        = each.value
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = aws_subnet.isolated[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]

  tags = {
    Name = "dify-vpce-${split(".", each.value)[length(split(".", each.value)) - 1]}"
  }
}

resource "aws_vpc_endpoint" "s3" {
  count             = local.is_isolated ? 1 : 0
  vpc_id            = aws_vpc.main[0].id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.isolated[0].id]

  tags = {
    Name = "dify-vpce-s3"
  }
}
