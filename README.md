# Dify on AWS — Terraform

Deploy [Dify](https://dify.ai/) (an open-source LLM application platform) on AWS with a single `terraform apply`.

## Architecture

```
                         ┌──────────┐
                         │ Route 53 │ (optional custom domain)
                         └────┬─────┘
                              │
                     ┌────────▼────────┐
                     │   CloudFront    │ (optional CDN + WAF)
                     └────────┬────────┘
                              │ VPC Origin
               ┌──────────────▼──────────────┐
               │   Application Load Balancer  │
               │  /api,/v1,/console → :5001   │
               │  /e/*             → :5002    │
               │  /*               → :3000    │
               └──────┬───────────┬───────────┘
                      │           │
          ┌───────────▼──┐  ┌────▼──────────┐
          │  ECS Fargate │  │  ECS Fargate  │
          │  API Service │  │  Web Service  │
          │ ┌──────────┐ │  │ ┌──────────┐  │
          │ │ dify-api │ │  │ │ dify-web │  │
          │ │ worker   │ │  │ │ (Next.js)│  │
          │ │ sandbox  │ │  │ └──────────┘  │
          │ │ plugin   │ │  └───────────────┘
          │ │ ext-kb   │ │
          │ └──────────┘ │
          └──┬────┬──────┘
             │    │
    ┌────────▼┐ ┌─▼──────────┐  ┌────────┐
    │ Aurora  │ │ ElastiCache │  │   S3   │
    │ PgSQL  │ │  Valkey 8.0 │  │Storage │
    │ v2     │ │  (Redis)    │  │        │
    └────────┘ └─────────────┘  └────────┘
```

## AWS Services Used

| Service | Purpose |
|---------|---------|
| **ECS Fargate** | Container orchestration (API, Worker, Web, Sandbox, Plugin Daemon) |
| **Aurora PostgreSQL Serverless v2** | Application database + pgvector for embeddings |
| **ElastiCache Valkey 8.0** | Cache, session store, and Celery message broker |
| **S3** | File storage, plugin packages, and access logs |
| **ALB** | Layer 7 load balancing with path-based routing |
| **CloudFront** | CDN with VPC Origin (optional) |
| **Route 53 + ACM** | Custom domain and TLS certificates (optional) |
| **WAF** | IP-based access control (optional, requires CloudFront) |
| **SES** | Transactional email via SMTP (optional) |
| **Secrets Manager / SSM** | Credentials and configuration management |
| **ECR** | Custom Docker image hosting (sandbox-init, external-knowledge-api) |

## Prerequisites

- [Terraform](https://www.terraform.io/) >= 1.5.0
- AWS CLI configured with appropriate credentials
- [Docker](https://www.docker.com/) (for building custom images during deployment)
- (Optional) Route 53 hosted zone for custom domain

## Quick Start

```bash
# 1. Clone the repository
git clone https://github.com/micci184/dify-on-aws-terraform.git
cd dify-on-aws-terraform

# 2. Configure Terraform backend
# Add your S3 backend settings to versions.tf:
#   backend "s3" {
#     bucket = "<your-tfstate-bucket>"
#     region = "<your-region>"
#   }
# Or use a separate file: terraform init -backend-config=backend.hcl

# 3. Create your configuration
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars as needed

# 4. Deploy
terraform init
terraform plan
terraform apply
```

After deployment, open the Dify URL shown in `terraform output dify_url` and create your admin account.

## Network

When creating a new VPC, the following CIDR layout is used:

| Subnet | CIDR |
|--------|------|
| VPC | `10.0.0.0/16` |
| Public subnets | `10.0.0.0/24`, `10.0.1.0/24` |
| Private subnets | `10.0.100.0/24`, `10.0.101.0/24` |

To use an existing VPC, set `vpc_id` in `terraform.tfvars`.

## Configuration

Key variables in `terraform.tfvars`:

| Variable | Default | Description |
|----------|---------|-------------|
| `aws_region` | `us-west-2` | AWS region for deployment |
| `dify_image_tag` | `1.11.4` | Dify container image version |
| `use_cloudfront` | `true` | Enable CloudFront CDN |
| `domain_name` | `null` | Route 53 domain (enables HTTPS + custom domain) |
| `sub_domain` | `dify` | Subdomain prefix (e.g., `dify.example.com`) |
| `use_nat_instance` | `false` | Use cheap NAT instance instead of NAT Gateway |
| `enable_aurora_scales_to_zero` | `false` | Allow Aurora to pause when idle |
| `is_redis_multi_az` | `true` | Multi-AZ ElastiCache with failover |
| `use_fargate_spot` | `false` | Use Fargate Spot for cost savings |
| `setup_email` | `false` | Configure SES email (requires `domain_name`) |
| `allowed_ipv4_cidrs` | `[]` | IP allowlist for WAF (empty = allow all) |

### Minimal Cost Configuration

```hcl
use_nat_instance             = true
enable_aurora_scales_to_zero = true   # Aurora pauses when idle
is_redis_multi_az            = false  # Single AZ (no failover)
use_fargate_spot             = true   # Spot capacity (may be interrupted)
```

### Deployment Patterns

| Pattern | Configuration |
|---------|--------------|
| **Default** | CloudFront + public ALB, auto-generated URL |
| **Custom domain** | `domain_name = "example.com"` |
| **No CloudFront** | `use_cloudfront = false` (requires `domain_name` for HTTPS) |
| **Private / internal** | `use_cloudfront = false`, `internal_alb = true` |
| **Isolated network** | `vpc_isolated = true`, `use_cloudfront = false`, `internal_alb = true` |
| **Existing VPC** | `vpc_id = "vpc-xxxx"` |

## Directory Structure

```
.
├── main.tf                        # Root module — orchestrates all child modules
├── variables.tf                   # Input variables
├── outputs.tf                     # Output values (Dify URL, ECS Exec command, etc.)
├── providers.tf                   # AWS provider configuration
├── versions.tf                    # Terraform and provider version constraints
├── terraform.tfvars.example       # Example variable values
│
├── docker/
│   ├── sandbox/                   # Dockerfile for sandbox init container
│   │   ├── Dockerfile
│   │   └── python-requirements.txt
│   └── external-knowledge-api/    # Bedrock Knowledge Base integration API
│       ├── Dockerfile
│       ├── app.py
│       ├── knowledge_service.py
│       └── requirements.txt
│
└── modules/
    ├── networking/                 # VPC, subnets, NAT, route tables, VPC endpoints
    ├── security/                   # Security groups (ALB, ECS, RDS, Redis)
    ├── storage/                    # S3 buckets (application files + access logs)
    ├── database/                   # Aurora PostgreSQL Serverless v2 + pgvector
    ├── cache/                      # ElastiCache Valkey (Redis-compatible)
    ├── alb/                        # Application Load Balancer + target groups
    ├── ecs/                        # ECS cluster, services, task definitions, IAM
    ├── cloudfront/                 # CloudFront distribution with VPC Origin
    ├── dns/                        # Route 53 records + ACM certificates
    ├── email/                      # SES domain identity + SMTP credentials
    └── waf/                        # WAFv2 IP-based access control
```

## Useful Commands

```bash
# Validate configuration
terraform validate

# Format all .tf files
terraform fmt -recursive

# Connect to API container via ECS Exec
terraform output -raw console_connect_command | bash

# View Dify URL
terraform output dify_url
```

## License

MIT
