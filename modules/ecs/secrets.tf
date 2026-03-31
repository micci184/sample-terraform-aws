# Encryption secret shared across API, Worker, Sandbox, Plugin Daemon
# CDK reuses the same secret for multiple env vars
resource "random_password" "encryption" {
  length  = 42
  special = true
}

resource "aws_secretsmanager_secret" "encryption" {
  name = "dify-encryption"

  tags = {
    Name = "dify-encryption"
  }
}

resource "aws_secretsmanager_secret_version" "encryption" {
  secret_id     = aws_secretsmanager_secret.encryption.id
  secret_string = random_password.encryption.result
}
