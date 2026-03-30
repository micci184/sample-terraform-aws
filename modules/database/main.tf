# ============================================================
# Aurora PostgreSQL Serverless v2
# ============================================================

resource "aws_db_subnet_group" "main" {
  name       = "dify-db"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "dify-db"
  }
}

resource "aws_rds_cluster_parameter_group" "main" {
  name   = "dify-aurora-pg15"
  family = "aurora-postgresql15"

  # Terminate idle sessions for Aurora Serverless v2 auto-pause
  parameter {
    name  = "idle_session_timeout"
    value = "60000"
  }

  tags = {
    Name = "dify-aurora-pg15"
  }
}

resource "aws_rds_cluster" "main" {
  cluster_identifier = "dify-db"
  engine             = "aurora-postgresql"
  engine_mode        = "provisioned"
  engine_version     = "15.12"
  database_name      = "main"

  manage_master_user_password = true
  storage_encrypted           = true
  enable_http_endpoint        = true
  deletion_protection         = false
  skip_final_snapshot         = true

  serverlessv2_scaling_configuration {
    min_capacity = var.enable_aurora_scales_to_zero ? 0 : 0.5
    max_capacity = 2.0
  }

  db_subnet_group_name            = aws_db_subnet_group.main.name
  vpc_security_group_ids          = [var.rds_security_group_id]
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.main.name

  tags = {
    Name = "dify-db"
  }
}

resource "aws_rds_cluster_instance" "writer" {
  identifier         = "dify-db-writer"
  cluster_identifier = aws_rds_cluster.main.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.main.engine
  engine_version     = aws_rds_cluster.main.engine_version

  publicly_accessible        = false
  auto_minor_version_upgrade = true

  tags = {
    Name = "dify-db-writer"
  }
}
