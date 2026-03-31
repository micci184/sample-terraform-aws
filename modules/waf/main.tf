# WAF Web ACL for CloudFront (CLOUDFRONT scope, must be in us-east-1)
# This module must receive providers = { aws = aws.us_east_1 }

locals {
  has_ipv4 = length(var.allowed_ipv4_cidrs) > 0
  has_ipv6 = length(var.allowed_ipv6_cidrs) > 0
}

resource "aws_wafv2_ip_set" "ipv4" {
  count              = local.has_ipv4 ? 1 : 0
  name               = "${var.name_prefix}-cloudfront-ipv4"
  scope              = "CLOUDFRONT"
  ip_address_version = "IPV4"
  addresses          = var.allowed_ipv4_cidrs

  tags = {
    Name = "${var.name_prefix}-cloudfront-ipv4"
  }
}

resource "aws_wafv2_ip_set" "ipv6" {
  count              = local.has_ipv6 ? 1 : 0
  name               = "${var.name_prefix}-cloudfront-ipv6"
  scope              = "CLOUDFRONT"
  ip_address_version = "IPV6"
  addresses          = var.allowed_ipv6_cidrs

  tags = {
    Name = "${var.name_prefix}-cloudfront-ipv6"
  }
}

resource "aws_wafv2_web_acl" "main" {
  name  = "${var.name_prefix}-cloudfront-waf"
  scope = "CLOUDFRONT"

  default_action {
    block {}
  }

  dynamic "rule" {
    for_each = local.has_ipv4 ? [1] : []
    content {
      name     = "IPv4AllowRule"
      priority = 1

      action {
        allow {}
      }

      statement {
        ip_set_reference_statement {
          arn = aws_wafv2_ip_set.ipv4[0].arn
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        sampled_requests_enabled   = true
        metric_name                = "${var.name_prefix}-ipv4-allow"
      }
    }
  }

  dynamic "rule" {
    for_each = local.has_ipv6 ? [1] : []
    content {
      name     = "IPv6AllowRule"
      priority = 2

      action {
        allow {}
      }

      statement {
        ip_set_reference_statement {
          arn = aws_wafv2_ip_set.ipv6[0].arn
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        sampled_requests_enabled   = true
        metric_name                = "${var.name_prefix}-ipv6-allow"
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    sampled_requests_enabled   = true
    metric_name                = "${var.name_prefix}-cloudfront-waf"
  }

  tags = {
    Name = "${var.name_prefix}-cloudfront-waf"
  }
}
