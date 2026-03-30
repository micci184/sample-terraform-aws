provider "aws" {
  region = var.aws_region
}

# Required for CloudFront WAF Web ACL and ACM certificate
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}
