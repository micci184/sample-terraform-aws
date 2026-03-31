# ============================================================
# Storage bucket (Dify application files, plugins)
# ============================================================

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "storage" {
  bucket        = "${var.name_prefix}-storage-${data.aws_caller_identity.current.account_id}-${var.aws_region}"
  force_destroy = true

  tags = {
    Name = "${var.name_prefix}-storage"
  }
}

resource "aws_s3_bucket_public_access_block" "storage" {
  bucket = aws_s3_bucket.storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "storage" {
  bucket = aws_s3_bucket.storage.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_policy" "storage_ssl" {
  bucket = aws_s3_bucket.storage.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnforceSSL"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.storage.arn,
          "${aws_s3_bucket.storage.arn}/*",
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# Plugin daemon placeholder object
# See: https://github.com/langgenius/dify-plugin-daemon/issues/35
resource "aws_s3_object" "plugins_placeholder" {
  bucket  = aws_s3_bucket.storage.id
  key     = "plugins"
  content = "placeholder for plugin daemon"
}

# ============================================================
# Access log bucket (ALB + CloudFront logs)
# ============================================================

resource "aws_s3_bucket" "access_log" {
  bucket        = "${var.name_prefix}-access-log-${data.aws_caller_identity.current.account_id}-${var.aws_region}"
  force_destroy = true

  tags = {
    Name = "${var.name_prefix}-access-log"
  }
}

resource "aws_s3_bucket_public_access_block" "access_log" {
  bucket = aws_s3_bucket.access_log.id

  block_public_acls       = true
  block_public_policy     = false
  ignore_public_acls      = true
  restrict_public_buckets = false
}

resource "aws_s3_bucket_server_side_encryption_configuration" "access_log" {
  bucket = aws_s3_bucket.access_log.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_ownership_controls" "access_log" {
  bucket = aws_s3_bucket.access_log.id

  rule {
    object_ownership = "ObjectWriter"
  }
}

data "aws_elb_service_account" "main" {}

resource "aws_s3_bucket_policy" "access_log" {
  bucket = aws_s3_bucket.access_log.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnforceSSL"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.access_log.arn,
          "${aws_s3_bucket.access_log.arn}/*",
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid    = "AllowALBLogs"
        Effect = "Allow"
        Principal = {
          AWS = data.aws_elb_service_account.main.arn
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.access_log.arn}/*"
      }
    ]
  })
}
