# ============================================================
# CloudFront VPC Origin (for internal ALB access)
# ============================================================

resource "aws_cloudfront_vpc_origin" "alb" {
  vpc_origin_endpoint_config {
    name                   = "dify-alb-vpc-origin-${var.aws_region}"
    arn                    = var.alb_arn
    http_port              = 80
    https_port             = 443
    origin_protocol_policy = "http-only"

    origin_ssl_protocols {
      items    = ["TLSv1.2"]
      quantity = 1
    }
  }

  tags = {
    Name = "dify-alb-vpc-origin"
  }
}

# ============================================================
# CloudFront Distribution
# ============================================================

locals {
  aliases = var.domain_name != null ? ["${var.sub_domain}.${var.domain_name}"] : []
}

resource "aws_cloudfront_distribution" "main" {
  comment     = "Dify distribution (${var.aws_region})"
  enabled     = true
  web_acl_id  = var.web_acl_arn
  aliases     = local.aliases
  price_class = "PriceClass_All"

  origin {
    domain_name = var.alb_dns_name
    origin_id   = "alb-vpc-origin"

    vpc_origin_config {
      vpc_origin_id            = aws_cloudfront_vpc_origin.alb.id
      origin_keepalive_timeout = 5
      origin_read_timeout      = 30
    }
  }

  default_cache_behavior {
    target_origin_id       = "alb-vpc-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    # Managed cache policy: UseOriginCacheControlHeadersQueryStrings
    cache_policy_id = "b2884449-e4de-46a7-ac36-70bc7f1ddd6d"
    # Managed origin request policy: AllViewer
    origin_request_policy_id = "216adef6-5c7f-47e4-b989-5492eafa07d3"
  }

  viewer_certificate {
    acm_certificate_arn            = var.certificate_arn
    ssl_support_method             = var.certificate_arn != null ? "sni-only" : null
    cloudfront_default_certificate = var.certificate_arn == null
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  logging_config {
    bucket          = var.access_log_bucket_domain
    prefix          = "dify-cloudfront/"
    include_cookies = false
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Name = "dify-cloudfront"
  }
}
