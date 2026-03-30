locals {
  is_internal = var.use_cloudfront || var.internal_alb
  subnets     = local.is_internal ? var.private_subnet_ids : var.public_subnet_ids
  use_https   = var.certificate_arn != null && !var.use_cloudfront
}

# ============================================================
# Application Load Balancer
# ============================================================

resource "aws_lb" "main" {
  name               = "dify-alb"
  internal           = local.is_internal
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = local.subnets
  idle_timeout       = 600

  access_logs {
    bucket  = var.access_log_bucket_id
    prefix  = "dify-alb"
    enabled = true
  }

  tags = {
    Name = "dify-alb"
  }
}

# ============================================================
# Listener
# ============================================================

resource "aws_lb_listener" "https" {
  count = local.use_https ? 1 : 0

  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      status_code  = "400"
    }
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = local.use_https ? "redirect" : "fixed-response"

    dynamic "redirect" {
      for_each = local.use_https ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }

    dynamic "fixed_response" {
      for_each = local.use_https ? [] : [1]
      content {
        content_type = "text/plain"
        status_code  = "400"
      }
    }
  }
}

locals {
  listener_arn = local.use_https ? aws_lb_listener.https[0].arn : aws_lb_listener.http.arn
}

# ============================================================
# Target Groups
# ============================================================

resource "aws_lb_target_group" "api" {
  name                 = "dify-api"
  port                 = 5001
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  target_type          = "ip"
  deregistration_delay = 10

  health_check {
    path                = "/health"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 10
    matcher             = "200-299,307"
  }

  tags = {
    Name = "dify-api"
  }
}

resource "aws_lb_target_group" "extension" {
  name                 = "dify-extension"
  port                 = 5002
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  target_type          = "ip"
  deregistration_delay = 10

  health_check {
    path                = "/health/check"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 10
    matcher             = "200-299,307"
  }

  tags = {
    Name = "dify-extension"
  }
}

resource "aws_lb_target_group" "web" {
  name                 = "dify-web"
  port                 = 3000
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  target_type          = "ip"
  deregistration_delay = 10

  health_check {
    path                = "/"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 10
    matcher             = "200-299,307"
  }

  tags = {
    Name = "dify-web"
  }
}

# ============================================================
# Listener Rules (path-based routing)
# ============================================================

# ALB limits 5 conditions per rule, so API paths are split into 2 rules
resource "aws_lb_listener_rule" "api_1" {
  listener_arn = local.listener_arn
  priority     = 1

  condition {
    path_pattern {
      values = ["/console/api", "/console/api/*", "/api", "/api/*", "/v1"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}

resource "aws_lb_listener_rule" "api_2" {
  listener_arn = local.listener_arn
  priority     = 2

  condition {
    path_pattern {
      values = ["/v1/*", "/files", "/files/*", "/triggers", "/triggers/*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}

resource "aws_lb_listener_rule" "extension" {
  listener_arn = local.listener_arn
  priority     = 3

  condition {
    path_pattern {
      values = ["/e", "/e/*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.extension.arn
  }
}

resource "aws_lb_listener_rule" "web" {
  listener_arn = local.listener_arn
  priority     = 4

  condition {
    path_pattern {
      values = ["/*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}
