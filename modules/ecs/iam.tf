# ============================================================
# Task Execution Role (pulls images, reads secrets)
# ============================================================

resource "aws_iam_role" "task_execution" {
  name = "dify-ecs-task-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "dify-ecs-task-execution"
  }
}

resource "aws_iam_role_policy_attachment" "task_execution_managed" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "task_execution_secrets" {
  name = "secrets-access"
  role = aws_iam_role.task_execution.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
        ]
        Resource = compact([
          var.db_secret_arn,
          var.redis_auth_secret_arn,
          aws_secretsmanager_secret.encryption.arn,
          var.email_smtp_secret_arn,
        ])
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameters",
        ]
        Resource = [
          var.broker_url_parameter_arn,
        ]
      },
    ]
  })
}

# ============================================================
# Task Role (application permissions)
# ============================================================

resource "aws_iam_role" "task" {
  name = "dify-ecs-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "dify-ecs-task"
  }
}

resource "aws_iam_role_policy" "task_s3" {
  name = "s3-access"
  role = aws_iam_role.task.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket",
      ]
      Resource = [
        var.storage_bucket_arn,
        "${var.storage_bucket_arn}/*",
      ]
    }]
  })
}

resource "aws_iam_role_policy" "task_bedrock" {
  name = "bedrock-access"
  role = aws_iam_role.task.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "bedrock:GetInferenceProfile",
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream",
        "bedrock:ListFoundationModels",
        "bedrock:Rerank",
        "bedrock:Retrieve",
        "bedrock:RetrieveAndGenerate",
      ]
      Resource = "*"
    }]
  })
}

# ECS Exec requires SSM permissions
resource "aws_iam_role_policy" "task_ssm" {
  name = "ssm-exec"
  role = aws_iam_role.task.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ssmmessages:CreateControlChannel",
        "ssmmessages:CreateDataChannel",
        "ssmmessages:OpenControlChannel",
        "ssmmessages:OpenDataChannel",
      ]
      Resource = "*"
    }]
  })
}
