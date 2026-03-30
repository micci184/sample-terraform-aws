# ============================================================
# API Task Definition (5+1 containers)
# ============================================================

locals {
  api_image = (
    local.ecr_base != null
    ? "${local.ecr_base}:dify-api_${var.dify_image_tag}"
    : "langgenius/dify-api:${var.dify_image_tag}"
  )
  sandbox_image = (
    local.ecr_base != null
    ? "${local.ecr_base}:dify-sandbox_${var.dify_sandbox_image_tag}"
    : "langgenius/dify-sandbox:${var.dify_sandbox_image_tag}"
  )
  plugin_daemon_image = (
    local.ecr_base != null
    ? "${local.ecr_base}:dify-plugin-daemon_${var.dify_plugin_daemon_image_tag}"
    : "langgenius/dify-plugin-daemon:${var.dify_plugin_daemon_image_tag}"
  )

  # Syscalls 0-456 for allow_any_syscalls
  all_syscalls = join(",", [for i in range(457) : tostring(i)])

  # Common DB secrets for container definitions
  db_secrets = [
    { name = "DB_USERNAME", valueFrom = "${var.db_secret_arn}:username::" },
    { name = "DB_HOST", valueFrom = "${var.db_secret_arn}:host::" },
    { name = "DB_PORT", valueFrom = "${var.db_secret_arn}:port::" },
    { name = "DB_PASSWORD", valueFrom = "${var.db_secret_arn}:password::" },
    { name = "PGVECTOR_USER", valueFrom = "${var.db_secret_arn}:username::" },
    { name = "PGVECTOR_HOST", valueFrom = "${var.db_secret_arn}:host::" },
    { name = "PGVECTOR_PORT", valueFrom = "${var.db_secret_arn}:port::" },
    { name = "PGVECTOR_PASSWORD", valueFrom = "${var.db_secret_arn}:password::" },
  ]

  redis_secrets = [
    { name = "REDIS_PASSWORD", valueFrom = var.redis_auth_secret_arn },
    { name = "CELERY_BROKER_URL", valueFrom = var.broker_url_parameter_arn },
  ]

  encryption_secrets = [
    { name = "SECRET_KEY", valueFrom = aws_secretsmanager_secret.encryption.arn },
    { name = "CODE_EXECUTION_API_KEY", valueFrom = aws_secretsmanager_secret.encryption.arn },
    { name = "INNER_API_KEY_FOR_PLUGIN", valueFrom = aws_secretsmanager_secret.encryption.arn },
    { name = "PLUGIN_DAEMON_KEY", valueFrom = aws_secretsmanager_secret.encryption.arn },
  ]

  email_secrets = local.has_email ? [
    { name = "SMTP_USERNAME", valueFrom = "${var.email_smtp_secret_arn}:username::" },
    { name = "SMTP_PASSWORD", valueFrom = "${var.email_smtp_secret_arn}:password::" },
  ] : []

  email_env = local.has_email ? {
    MAIL_TYPE              = "smtp"
    SMTP_SERVER            = var.email_smtp_server
    SMTP_PORT              = var.email_smtp_port
    SMTP_USE_TLS           = "true"
    MAIL_DEFAULT_SEND_FROM = "no-reply@${var.email_domain_name}"
  } : {}
}

resource "aws_cloudwatch_log_group" "api" {
  name              = "/ecs/dify-api"
  retention_in_days = 30

  tags = {
    Name = "dify-api"
  }
}

resource "aws_ecs_task_definition" "api" {
  family                   = "dify-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 1024
  memory                   = 2048
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  volume {
    name = "sandbox"
  }

  container_definitions = jsonencode([
    # 1. Main API container
    {
      name      = "dify-api"
      image     = local.api_image
      essential = true
      portMappings = [{ containerPort = local.api_port }]
      environment = [for k, v in merge({
        MODE                       = "api"
        LOG_LEVEL                  = "ERROR"
        DEBUG                      = "false"
        CONSOLE_WEB_URL            = var.alb_url
        CONSOLE_API_URL            = var.alb_url
        SERVICE_API_URL            = var.alb_url
        APP_WEB_URL                = var.alb_url
        TRIGGER_URL                = var.alb_url
        SQLALCHEMY_POOL_PRE_PING   = "True"
        REDIS_HOST                 = var.redis_endpoint
        REDIS_PORT                 = tostring(var.redis_port)
        REDIS_USE_SSL              = "true"
        REDIS_DB                   = "0"
        WEB_API_CORS_ALLOW_ORIGINS = "*"
        CONSOLE_CORS_ALLOW_ORIGINS = "*"
        STORAGE_TYPE               = "s3"
        S3_BUCKET_NAME             = var.storage_bucket_id
        S3_REGION                  = var.aws_region
        S3_USE_AWS_MANAGED_IAM     = "true"
        DB_DATABASE                = var.db_database_name
        VECTOR_STORE               = "pgvector"
        PGVECTOR_DATABASE          = var.pgvector_database_name
        CODE_EXECUTION_ENDPOINT    = "http://localhost:${local.sandbox_port}"
        PLUGIN_DAEMON_URL          = "http://localhost:${local.plugin_port}"
        MARKETPLACE_API_URL        = "https://marketplace.dify.ai"
        MARKETPLACE_URL            = "https://marketplace.dify.ai"
        TEXT_GENERATION_TIMEOUT_MS  = "600000"
        ENDPOINT_URL_TEMPLATE      = "${var.alb_url}/e/{hook_id}"
      }, local.email_env) : { name = k, value = v }]
      secrets = concat(local.db_secrets, local.redis_secrets, local.encryption_secrets, local.email_secrets)
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${local.api_port}/health || exit 1"]
        interval    = 15
        startPeriod = 90
        timeout     = 5
        retries     = 10
      }
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.api.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "api"
        }
      }
    },

    # 2. Worker container (Celery background jobs)
    {
      name      = "dify-worker"
      image     = local.api_image
      essential = true
      environment = [for k, v in merge({
        MODE                      = "worker"
        LOG_LEVEL                 = "ERROR"
        DEBUG                     = "false"
        CONSOLE_WEB_URL           = var.alb_url
        CONSOLE_API_URL           = var.alb_url
        SERVICE_API_URL           = var.alb_url
        APP_WEB_URL               = var.alb_url
        MIGRATION_ENABLED         = "true"
        SQLALCHEMY_POOL_PRE_PING  = "True"
        REDIS_HOST                = var.redis_endpoint
        REDIS_PORT                = tostring(var.redis_port)
        REDIS_USE_SSL             = "true"
        REDIS_DB                  = "0"
        STORAGE_TYPE              = "s3"
        S3_BUCKET_NAME            = var.storage_bucket_id
        S3_REGION                 = var.aws_region
        DB_DATABASE               = var.db_database_name
        VECTOR_STORE              = "pgvector"
        PGVECTOR_DATABASE         = var.pgvector_database_name
        PLUGIN_DAEMON_URL         = "http://localhost:${local.plugin_port}"
        CODE_EXECUTION_ENDPOINT   = "http://localhost:${local.sandbox_port}"
        MARKETPLACE_API_URL       = "https://marketplace.dify.ai"
        MARKETPLACE_URL           = "https://marketplace.dify.ai"
      }, local.email_env) : { name = k, value = v }]
      secrets = concat(local.db_secrets, local.redis_secrets, [
        { name = "SECRET_KEY", valueFrom = aws_secretsmanager_secret.encryption.arn },
        { name = "CODE_EXECUTION_API_KEY", valueFrom = aws_secretsmanager_secret.encryption.arn },
        { name = "PLUGIN_DAEMON_KEY", valueFrom = aws_secretsmanager_secret.encryption.arn },
      ], local.email_secrets)
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.api.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "worker"
        }
      }
    },

    # 3. Sandbox file mount (init container)
    {
      name      = "sandbox-file-mount"
      image     = var.sandbox_init_image_uri
      essential = false
      mountPoints = [{
        containerPath = "/dependencies"
        sourceVolume  = "sandbox"
        readOnly      = false
      }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.api.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "sandbox-init"
        }
      }
    },

    # 4. Sandbox container (code execution)
    {
      name      = "dify-sandbox"
      image     = local.sandbox_image
      essential = true
      portMappings = [{ containerPort = local.sandbox_port }]
      environment = concat(
        [
          { name = "GIN_MODE", value = "release" },
          { name = "WORKER_TIMEOUT", value = "15" },
          { name = "ENABLE_NETWORK", value = "true" },
        ],
        var.allow_any_syscalls ? [{ name = "ALLOWED_SYSCALLS", value = local.all_syscalls }] : []
      )
      secrets = [
        { name = "API_KEY", valueFrom = aws_secretsmanager_secret.encryption.arn },
      ]
      mountPoints = [{
        containerPath = "/dependencies"
        sourceVolume  = "sandbox"
        readOnly      = true
      }]
      dependsOn = [{
        containerName = "sandbox-file-mount"
        condition     = "COMPLETE"
      }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.api.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "sandbox"
        }
      }
    },

    # 5. Plugin Daemon container
    {
      name      = "dify-plugin-daemon"
      image     = local.plugin_daemon_image
      essential = true
      portMappings = [
        { containerPort = local.plugin_port },
        { containerPort = 5003 },
      ]
      environment = [for k, v in {
        GIN_MODE                                  = "release"
        REDIS_HOST                                = var.redis_endpoint
        REDIS_PORT                                = tostring(var.redis_port)
        REDIS_USE_SSL                             = "true"
        DB_DATABASE                               = "dify_plugin"
        DB_SSL_MODE                               = "disable"
        SERVER_PORT                               = tostring(local.plugin_port)
        AWS_REGION                                = var.aws_region
        PLUGIN_STORAGE_TYPE                       = "aws_s3"
        PLUGIN_STORAGE_OSS_BUCKET                 = var.storage_bucket_id
        PLUGIN_INSTALLED_PATH                     = "plugins"
        PLUGIN_MAX_EXECUTION_TIMEOUT              = "600"
        MAX_PLUGIN_PACKAGE_SIZE                   = "52428800"
        MAX_BUNDLE_PACKAGE_SIZE                   = "52428800"
        PLUGIN_REMOTE_INSTALLING_ENABLED          = "true"
        PLUGIN_REMOTE_INSTALLING_HOST             = "localhost"
        PLUGIN_REMOTE_INSTALLING_PORT             = "5003"
        TEXT_GENERATION_TIMEOUT_MS                 = "600000"
        ROUTINE_POOL_SIZE                         = "10000"
        LIFETIME_COLLECTION_HEARTBEAT_INTERVAL    = "5"
        LIFETIME_COLLECTION_GC_INTERVAL           = "60"
        LIFETIME_STATE_GC_INTERVAL                = "300"
        DIFY_INVOCATION_CONNECTION_IDLE_TIMEOUT   = "120"
        PYTHON_ENV_INIT_TIMEOUT                   = "120"
        DIFY_INNER_API_URL                        = "http://localhost:${local.api_port}"
        PLUGIN_WORKING_PATH                       = "/app/storage/cwd"
        FORCE_VERIFYING_SIGNATURE                 = "true"
        S3_USE_AWS_MANAGED_IAM                    = "true"
        S3_ENDPOINT                               = "https://s3.${var.aws_region}.amazonaws.com"
      } : { name = k, value = v }]
      secrets = concat(local.db_secrets, local.redis_secrets, [
        { name = "DIFY_INNER_API_KEY", valueFrom = aws_secretsmanager_secret.encryption.arn },
        { name = "SERVER_KEY", valueFrom = aws_secretsmanager_secret.encryption.arn },
      ])
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.api.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "plugin-daemon"
        }
      }
    },

    # 6. External Knowledge Base API (Bedrock KB integration)
    {
      name      = "external-knowledge-api"
      image     = var.external_kb_image_uri
      essential = false
      portMappings = [{ containerPort = local.ext_kb_port }]
      environment = [
        { name = "BEARER_TOKEN", value = "dummy-key" },
        { name = "BEDROCK_REGION", value = "us-west-2" },
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.api.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ext-kb"
        }
      }
    },
  ])

  tags = {
    Name = "dify-api"
  }
}

# ============================================================
# API Fargate Service
# ============================================================

resource "aws_ecs_service" "api" {
  name            = "dify-api"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = 1

  enable_execute_command = true

  capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = var.use_fargate_spot ? 0 : 1
  }

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = var.use_fargate_spot ? 1 : 0
  }

  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [var.ecs_security_group_id]
  }

  # API target group (port 5001)
  load_balancer {
    target_group_arn = var.api_target_group_arn
    container_name   = "dify-api"
    container_port   = local.api_port
  }

  # Plugin daemon target group (port 5002)
  load_balancer {
    target_group_arn = var.extension_target_group_arn
    container_name   = "dify-plugin-daemon"
    container_port   = local.plugin_port
  }

  deployment_minimum_healthy_percent = 100

  tags = {
    Name = "dify-api"
  }
}
