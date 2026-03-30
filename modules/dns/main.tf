data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}

# ============================================================
# ACM Certificate (main region, for ALB)
# ============================================================

resource "aws_acm_certificate" "main" {
  domain_name               = "*.${var.domain_name}"
  subject_alternative_names = [var.domain_name]
  validation_method         = "DNS"

  tags = {
    Name = "dify-main-cert"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id = data.aws_route53_zone.main.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 300
}

resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# ============================================================
# ACM Certificate (us-east-1, for CloudFront)
# ============================================================

resource "aws_acm_certificate" "cloudfront" {
  count    = var.use_cloudfront ? 1 : 0
  provider = aws.us_east_1

  domain_name               = "*.${var.domain_name}"
  subject_alternative_names = [var.domain_name]
  validation_method         = "DNS"

  tags = {
    Name = "dify-cloudfront-cert"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# DNS validation records are shared with the main cert (same domain)
resource "aws_acm_certificate_validation" "cloudfront" {
  count    = var.use_cloudfront ? 1 : 0
  provider = aws.us_east_1

  certificate_arn         = aws_acm_certificate.cloudfront[0].arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# ============================================================
# Route53 A Record (alias to CloudFront or ALB)
# ============================================================

resource "aws_route53_record" "app" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "${var.sub_domain}.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.target_dns_name
    zone_id                = var.target_zone_id
    evaluate_target_health = true
  }
}
