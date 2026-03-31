# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository deploys [Dify](https://dify.ai/) (an open-source LLM application platform) on AWS using Terraform.

- **Remote:** https://github.com/micci184/dify-on-aws-terraform.git
- **IaC Tool:** Terraform
- **Cloud Provider:** AWS

## Common Commands

```bash
# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Format fix
terraform fmt -recursive

# Plan changes
terraform plan

# Apply changes
terraform apply
```
## Conversation Guidelines

- Claude Code との会話は常に日本語で行う
- コード内のコメントは英語で記述
- Git commit メッセージは英語で記述
- GitHub PR のタイトル・説明は英語で記述
- README.md などのドキュメントは英語で作成
- 変数名・リソース名などのコード上の命名も英語
