# ============================================================
# ElastiCache Valkey 8.0 (Redis-compatible)
# ============================================================

resource "random_password" "redis_auth" {
  length  = 30
  special = false
}

resource "aws_secretsmanager_secret" "redis_auth" {
  name_prefix = "dify-redis-auth-"

  tags = {
    Name = "dify-redis-auth"
  }
}

resource "aws_secretsmanager_secret_version" "redis_auth" {
  secret_id     = aws_secretsmanager_secret.redis_auth.id
  secret_string = random_password.redis_auth.result
}

resource "aws_elasticache_subnet_group" "main" {
  name       = "dify-cache"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "dify-cache"
  }
}

resource "aws_elasticache_replication_group" "main" {
  replication_group_id = "dify-cache"
  description          = "Dify cache/queue cluster"
  engine               = "valkey"
  engine_version       = "8.0"
  node_type            = "cache.t4g.micro"
  port                 = 6379
  parameter_group_name = "default.valkey8"

  num_node_groups         = 1
  replicas_per_node_group = var.is_redis_multi_az ? 1 : 0

  automatic_failover_enabled = var.is_redis_multi_az
  multi_az_enabled           = var.is_redis_multi_az

  subnet_group_name  = aws_elasticache_subnet_group.main.name
  security_group_ids = [var.redis_security_group_id]

  transit_encryption_enabled = true
  at_rest_encryption_enabled = true
  auth_token                 = random_password.redis_auth.result

  tags = {
    Name = "dify-cache"
  }
}

# Celery broker URL stored in SSM Parameter Store
resource "aws_ssm_parameter" "broker_url" {
  name  = "/dify/redis/broker-url"
  type  = "SecureString"
  value = "rediss://:${random_password.redis_auth.result}@${aws_elasticache_replication_group.main.primary_endpoint_address}:6379/1?ssl_cert_reqs=optional"

  tags = {
    Name = "dify-redis-broker-url"
  }
}
