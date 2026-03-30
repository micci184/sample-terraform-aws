data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.max_azs)

  create_vpc   = var.vpc_id == null
  is_standard  = local.create_vpc && !var.vpc_isolated
  is_isolated  = local.create_vpc && var.vpc_isolated
  is_imported  = !local.create_vpc

  vpc_id = (
    local.is_imported
    ? data.aws_vpc.imported[0].id
    : aws_vpc.main[0].id
  )

  vpc_cidr_block = (
    local.is_imported
    ? data.aws_vpc.imported[0].cidr_block
    : aws_vpc.main[0].cidr_block
  )

  public_subnet_ids = local.is_standard ? aws_subnet.public[*].id : []

  private_subnet_ids = (
    local.is_imported
    ? data.aws_subnets.private[0].ids
    : local.is_isolated
      ? aws_subnet.isolated[*].id
      : aws_subnet.private[*].id
  )
}

# ============================================================
# Import existing VPC
# ============================================================

data "aws_vpc" "imported" {
  count = local.is_imported ? 1 : 0
  id    = var.vpc_id
}

data "aws_subnets" "private" {
  count = local.is_imported ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }

  tags = {
    "aws-cdk:subnet-type" = "Private"
  }
}

# ============================================================
# Create new VPC
# ============================================================

resource "aws_vpc" "main" {
  count = local.create_vpc ? 1 : 0

  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "dify-vpc"
  }
}

# ============================================================
# Standard mode: public + private subnets with NAT
# ============================================================

resource "aws_internet_gateway" "main" {
  count  = local.is_standard ? 1 : 0
  vpc_id = aws_vpc.main[0].id

  tags = {
    Name = "dify-igw"
  }
}

resource "aws_subnet" "public" {
  count = local.is_standard ? var.max_azs : 0

  vpc_id                  = aws_vpc.main[0].id
  cidr_block              = cidrsubnet(aws_vpc.main[0].cidr_block, 8, count.index)
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "dify-public-${local.azs[count.index]}"
  }
}

resource "aws_subnet" "private" {
  count = local.is_standard ? var.max_azs : 0

  vpc_id            = aws_vpc.main[0].id
  cidr_block        = cidrsubnet(aws_vpc.main[0].cidr_block, 8, count.index + 100)
  availability_zone = local.azs[count.index]

  tags = {
    Name = "dify-private-${local.azs[count.index]}"
  }
}

# Public route table
resource "aws_route_table" "public" {
  count  = local.is_standard ? 1 : 0
  vpc_id = aws_vpc.main[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main[0].id
  }

  tags = {
    Name = "dify-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = local.is_standard ? var.max_azs : 0
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
}

# Private route table
resource "aws_route_table" "private" {
  count  = local.is_standard ? 1 : 0
  vpc_id = aws_vpc.main[0].id

  tags = {
    Name = "dify-private-rt"
  }
}

resource "aws_route_table_association" "private" {
  count          = local.is_standard ? var.max_azs : 0
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[0].id
}

# ---- NAT Gateway (default) ----

resource "aws_eip" "nat" {
  count  = local.is_standard && !var.use_nat_instance ? 1 : 0
  domain = "vpc"

  tags = {
    Name = "dify-nat-eip"
  }
}

resource "aws_nat_gateway" "main" {
  count         = local.is_standard && !var.use_nat_instance ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "dify-nat-gw"
  }
}

resource "aws_route" "private_nat_gateway" {
  count                  = local.is_standard && !var.use_nat_instance ? 1 : 0
  route_table_id         = aws_route_table.private[0].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[0].id
}

# ---- NAT Instance (cost-saving alternative) ----

data "aws_ssm_parameter" "al2023_arm64" {
  count = local.is_standard && var.use_nat_instance ? 1 : 0
  name  = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

resource "aws_security_group" "nat_instance" {
  count  = local.is_standard && var.use_nat_instance ? 1 : 0
  name   = "dify-nat-instance"
  vpc_id = aws_vpc.main[0].id

  ingress {
    description = "Allow traffic from private subnets"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [aws_vpc.main[0].cidr_block]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "dify-nat-instance"
  }
}

resource "aws_instance" "nat" {
  count = local.is_standard && var.use_nat_instance ? 1 : 0

  ami                         = data.aws_ssm_parameter.al2023_arm64[0].value
  instance_type               = "t4g.nano"
  subnet_id                   = aws_subnet.public[0].id
  source_dest_check           = false
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.nat_instance[0].id]

  user_data = <<-EOF
    #!/bin/bash
    sysctl -w net.ipv4.ip_forward=1
    echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
    yum install -y iptables-services
    iptables -t nat -A POSTROUTING -o ens5 -j MASQUERADE
    service iptables save
    systemctl enable iptables
  EOF

  tags = {
    Name = "dify-nat-instance"
  }
}

resource "aws_route" "private_nat_instance" {
  count                  = local.is_standard && var.use_nat_instance ? 1 : 0
  route_table_id         = aws_route_table.private[0].id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.nat[0].primary_network_interface_id
}

# ============================================================
# Isolated mode: private isolated subnets only
# ============================================================

resource "aws_subnet" "isolated" {
  count = local.is_isolated ? var.max_azs : 0

  vpc_id            = aws_vpc.main[0].id
  cidr_block        = cidrsubnet(aws_vpc.main[0].cidr_block, 8, count.index)
  availability_zone = local.azs[count.index]

  tags = {
    Name = "dify-isolated-${local.azs[count.index]}"
  }
}

resource "aws_route_table" "isolated" {
  count  = local.is_isolated ? 1 : 0
  vpc_id = aws_vpc.main[0].id

  tags = {
    Name = "dify-isolated-rt"
  }
}

resource "aws_route_table_association" "isolated" {
  count          = local.is_isolated ? var.max_azs : 0
  subnet_id      = aws_subnet.isolated[count.index].id
  route_table_id = aws_route_table.isolated[0].id
}
