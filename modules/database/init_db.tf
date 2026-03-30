# Initialize pgvector database and extension via RDS Data API
# Replaces CDK AwsCustomResource for SQL execution

resource "terraform_data" "init_pgvector" {
  depends_on = [aws_rds_cluster_instance.writer]

  triggers_replace = [aws_rds_cluster.main.arn]

  provisioner "local-exec" {
    command = <<-EOT
      # Create pgvector database
      aws rds-data execute-statement \
        --resource-arn "${aws_rds_cluster.main.arn}" \
        --secret-arn "${aws_rds_cluster.main.master_user_secret[0].secret_arn}" \
        --sql "SELECT 'CREATE DATABASE pgvector' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'pgvector')" \
        --region "${var.aws_region}" \
        --no-cli-pager

      # The above SELECT-based approach may not actually create the DB.
      # Use a DO block instead for conditional creation.
      aws rds-data execute-statement \
        --resource-arn "${aws_rds_cluster.main.arn}" \
        --secret-arn "${aws_rds_cluster.main.master_user_secret[0].secret_arn}" \
        --sql "DO \$\$ BEGIN IF NOT EXISTS (SELECT FROM pg_database WHERE datname = 'pgvector') THEN PERFORM dblink_exec('dbname=main', 'CREATE DATABASE pgvector'); END IF; END \$\$;" \
        --region "${var.aws_region}" \
        --no-cli-pager || \
      aws rds-data execute-statement \
        --resource-arn "${aws_rds_cluster.main.arn}" \
        --secret-arn "${aws_rds_cluster.main.master_user_secret[0].secret_arn}" \
        --sql "CREATE DATABASE pgvector" \
        --region "${var.aws_region}" \
        --no-cli-pager || true

      # Install pgvector extension in pgvector database
      aws rds-data execute-statement \
        --resource-arn "${aws_rds_cluster.main.arn}" \
        --secret-arn "${aws_rds_cluster.main.master_user_secret[0].secret_arn}" \
        --database "pgvector" \
        --sql "CREATE EXTENSION IF NOT EXISTS vector" \
        --region "${var.aws_region}" \
        --no-cli-pager
    EOT
  }
}
