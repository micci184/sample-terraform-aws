# ============================================================
# Web Task Definition (Next.js frontend)
# ============================================================

locals {
  web_image = (
    local.ecr_base != null
    ? "${local.ecr_base}:dify-web_${var.dify_image_tag}"
    : "langgenius/dify-web:${var.dify_image_tag}"
  )
}

resource "aws_cloudwatch_log_group" "web" {
  name              = "/ecs/dify-web"
  retention_in_days = 30

  tags = {
    Name = "dify-web"
  }
}

resource "aws_ecs_task_definition" "web" {
  family                   = "dify-web"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name      = "dify-web"
      image     = local.web_image
      essential = true
      portMappings = [{ containerPort = local.web_port }]
      environment = [for k, v in {
        LOG_LEVEL           = "ERROR"
        DEBUG               = "false"
        CONSOLE_API_URL     = var.alb_url
        APP_API_URL         = var.alb_url
        HOSTNAME            = "0.0.0.0"
        PORT                = tostring(local.web_port)
        MARKETPLACE_API_URL = "https://marketplace.dify.ai"
        MARKETPLACE_URL     = "https://marketplace.dify.ai"
      } : { name = k, value = v }]
      healthCheck = {
        # Use wget instead of curl (Alpine-based image)
        command     = ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:${local.web_port}/ || exit 1"]
        interval    = 15
        startPeriod = 30
        timeout     = 5
        retries     = 3
      }
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.web.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "web"
        }
      }
    },
  ])

  tags = {
    Name = "dify-web"
  }
}

# ============================================================
# Web Fargate Service
# ============================================================

resource "aws_ecs_service" "web" {
  name            = "dify-web"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.web.arn
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

  load_balancer {
    target_group_arn = var.web_target_group_arn
    container_name   = "dify-web"
    container_port   = local.web_port
  }

  deployment_minimum_healthy_percent = 100

  tags = {
    Name = "dify-web"
  }
}
