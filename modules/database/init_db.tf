# Initialize pgvector database and extension via RDS Data API

resource "terraform_data" "create_pgvector_db" {
  depends_on = [aws_rds_cluster_instance.writer]

  triggers_replace = [aws_rds_cluster.main.arn]

  provisioner "local-exec" {
    command = <<-EOT
      aws rds-data execute-statement \
        --resource-arn "${aws_rds_cluster.main.arn}" \
        --secret-arn "${aws_rds_cluster.main.master_user_secret[0].secret_arn}" \
        --database "main" \
        --sql "CREATE DATABASE pgvector" \
        --region "${var.aws_region}" \
        --no-cli-pager || true
    EOT
  }
}

resource "terraform_data" "init_pgvector_extension" {
  depends_on = [terraform_data.create_pgvector_db]

  triggers_replace = [aws_rds_cluster.main.arn]

  provisioner "local-exec" {
    command = <<-EOT
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
