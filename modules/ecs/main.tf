data "aws_caller_identity" "current" {}

locals {
  account_id    = data.aws_caller_identity.current.account_id
  ecr_base      = var.custom_ecr_repository_name != null ? "${local.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.custom_ecr_repository_name}" : null
  has_email     = var.email_smtp_secret_arn != null
  api_port      = 5001
  plugin_port   = 5002
  web_port      = 3000
  sandbox_port  = 8194
  ext_kb_port   = 8000
}

# ============================================================
# ECS Cluster
# ============================================================

resource "aws_ecs_cluster" "main" {
  name = "dify"

  setting {
    name  = "containerInsights"
    value = "enhanced"
  }

  tags = {
    Name = "dify"
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]
}
