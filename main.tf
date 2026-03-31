# ============================================================
# Networking
# ============================================================

module "networking" {
  source = "./modules/networking"

  vpc_id           = var.vpc_id
  vpc_isolated     = var.vpc_isolated
  use_nat_instance = var.use_nat_instance
  aws_region       = var.aws_region
}

# ============================================================
# Security Groups
# ============================================================

module "security" {
  source = "./modules/security"

  vpc_id             = module.networking.vpc_id
  use_cloudfront     = var.use_cloudfront
  internal_alb       = var.internal_alb
  allowed_ipv4_cidrs = var.allowed_ipv4_cidrs
  allowed_ipv6_cidrs = var.allowed_ipv6_cidrs
}

# ============================================================
# Storage
# ============================================================

module "storage" {
  source     = "./modules/storage"
  aws_region = var.aws_region
}

# ============================================================
# Database
# ============================================================

module "database" {
  source = "./modules/database"

  private_subnet_ids           = module.networking.private_subnet_ids
  rds_security_group_id        = module.security.rds_security_group_id
  enable_aurora_scales_to_zero = var.enable_aurora_scales_to_zero
  aws_region                   = var.aws_region
}

# ============================================================
# Cache
# ============================================================

module "cache" {
  source = "./modules/cache"

  private_subnet_ids      = module.networking.private_subnet_ids
  redis_security_group_id = module.security.redis_security_group_id
  is_redis_multi_az       = var.is_redis_multi_az
}

# ============================================================
# ALB
# ============================================================

module "alb" {
  source = "./modules/alb"

  vpc_id                = module.networking.vpc_id
  public_subnet_ids     = module.networking.public_subnet_ids
  private_subnet_ids    = module.networking.private_subnet_ids
  alb_security_group_id = module.security.alb_security_group_id
  access_log_bucket_id  = module.storage.access_log_bucket_id
  use_cloudfront        = var.use_cloudfront
  internal_alb          = var.internal_alb
  certificate_arn       = local.main_certificate_arn
}

# ============================================================
# WAF (us-east-1, for CloudFront)
# ============================================================

module "waf" {
  count  = local.create_waf ? 1 : 0
  source = "./modules/waf"

  providers = {
    aws = aws.us_east_1
  }

  allowed_ipv4_cidrs = var.allowed_ipv4_cidrs
  allowed_ipv6_cidrs = var.allowed_ipv6_cidrs
}

# ============================================================
# DNS & Certificates
# ============================================================

module "dns" {
  count  = var.domain_name != null ? 1 : 0
  source = "./modules/dns"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  domain_name     = var.domain_name
  sub_domain      = var.sub_domain
  use_cloudfront  = var.use_cloudfront
  target_dns_name = local.dns_target_name
  target_zone_id  = local.dns_target_zone_id
}

# ============================================================
# CloudFront
# ============================================================

module "cloudfront" {
  count  = var.use_cloudfront ? 1 : 0
  source = "./modules/cloudfront"

  alb_arn                  = module.alb.alb_arn
  alb_dns_name             = module.alb.alb_dns_name
  access_log_bucket_domain = module.storage.access_log_bucket_domain
  aws_region               = var.aws_region
  web_acl_arn              = local.create_waf ? module.waf[0].web_acl_arn : null
  certificate_arn          = local.cloudfront_certificate_arn
  domain_name              = var.domain_name
  sub_domain               = var.sub_domain
}

# ============================================================
# Email (optional)
# ============================================================

module "email" {
  count  = var.setup_email ? 1 : 0
  source = "./modules/email"

  domain_name    = var.domain_name
  hosted_zone_id = module.dns[0].hosted_zone_id
  aws_region     = var.aws_region
}

# ============================================================
# ECR for custom Docker images
# ============================================================

resource "aws_ecr_repository" "sandbox_init" {
  name                 = "dify-sandbox-init"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  tags = {
    Name = "dify-sandbox-init"
  }
}

resource "aws_ecr_repository" "external_kb" {
  name                 = "dify-external-knowledge-api"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  tags = {
    Name = "dify-external-knowledge-api"
  }
}

resource "terraform_data" "build_sandbox_init" {
  triggers_replace = [filesha256("${path.module}/docker/sandbox/Dockerfile")]

  provisioner "local-exec" {
    command = <<-EOT
      aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com
      docker build --platform linux/amd64 -t ${aws_ecr_repository.sandbox_init.repository_url}:latest ${path.module}/docker/sandbox/
      docker push ${aws_ecr_repository.sandbox_init.repository_url}:latest
    EOT
  }
}

resource "terraform_data" "build_external_kb" {
  triggers_replace = [filesha256("${path.module}/docker/external-knowledge-api/Dockerfile")]

  provisioner "local-exec" {
    command = <<-EOT
      aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com
      docker build --platform linux/amd64 -t ${aws_ecr_repository.external_kb.repository_url}:latest ${path.module}/docker/external-knowledge-api/
      docker push ${aws_ecr_repository.external_kb.repository_url}:latest
    EOT
  }
}

# ============================================================
# ECS
# ============================================================

module "ecs" {
  source = "./modules/ecs"

  aws_region            = var.aws_region
  private_subnet_ids    = module.networking.private_subnet_ids
  ecs_security_group_id = module.security.ecs_security_group_id

  # Storage
  storage_bucket_id  = module.storage.storage_bucket_id
  storage_bucket_arn = module.storage.storage_bucket_arn

  # Database
  db_secret_arn          = module.database.master_secret_arn
  db_endpoint            = module.database.cluster_endpoint
  db_port                = module.database.cluster_port
  db_database_name       = module.database.database_name
  pgvector_database_name = module.database.pgvector_database_name

  # Cache
  redis_endpoint           = module.cache.primary_endpoint
  redis_port               = module.cache.port
  redis_auth_secret_arn    = module.cache.auth_token_secret_arn
  broker_url_parameter_arn = module.cache.broker_url_parameter_arn

  # Container images
  dify_image_tag               = var.dify_image_tag
  dify_sandbox_image_tag       = var.dify_sandbox_image_tag
  dify_plugin_daemon_image_tag = var.dify_plugin_daemon_image_tag
  custom_ecr_repository_name   = var.custom_ecr_repository_name
  sandbox_init_image_uri       = "${aws_ecr_repository.sandbox_init.repository_url}:latest"
  external_kb_image_uri        = "${aws_ecr_repository.external_kb.repository_url}:latest"

  # Feature flags
  allow_any_syscalls = var.allow_any_syscalls
  use_fargate_spot   = var.use_fargate_spot

  # ALB
  alb_url                    = local.dify_url
  api_target_group_arn       = module.alb.api_target_group_arn
  extension_target_group_arn = module.alb.extension_target_group_arn
  web_target_group_arn       = module.alb.web_target_group_arn

  # Email (optional)
  email_smtp_secret_arn = var.setup_email ? module.email[0].smtp_secret_arn : null
  email_smtp_server     = var.setup_email ? module.email[0].smtp_server : null
  email_smtp_port       = var.setup_email ? module.email[0].smtp_port : null
  email_domain_name     = var.setup_email ? module.email[0].domain_name : null

  depends_on = [
    terraform_data.build_sandbox_init,
    terraform_data.build_external_kb,
  ]
}

# ============================================================
# Locals for cross-module references
# ============================================================

data "aws_caller_identity" "current" {}

locals {
  create_waf = var.use_cloudfront && (length(var.allowed_ipv4_cidrs) > 0 || length(var.allowed_ipv6_cidrs) > 0)

  # Certificate ARNs
  main_certificate_arn       = var.domain_name != null && !var.use_cloudfront ? module.dns[0].certificate_arn : null
  cloudfront_certificate_arn = var.domain_name != null && var.use_cloudfront ? module.dns[0].cloudfront_certificate_arn : null

  # DNS record target
  dns_target_name = (
    var.use_cloudfront
    ? module.cloudfront[0].distribution_domain_name
    : module.alb.alb_dns_name
  )
  dns_target_zone_id = (
    var.use_cloudfront
    ? module.cloudfront[0].distribution_hosted_zone_id
    : module.alb.alb_zone_id
  )

  # Dify URL for container environment variables
  dify_url = (
    var.domain_name != null
    ? "https://${var.sub_domain}.${var.domain_name}"
    : var.use_cloudfront
    ? "https://${module.cloudfront[0].distribution_domain_name}"
    : module.alb.alb_url
  )
}
