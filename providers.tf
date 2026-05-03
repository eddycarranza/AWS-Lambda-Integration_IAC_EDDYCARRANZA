terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Project     = "image-processor"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Prefix list del S3 Gateway Endpoint (evita dependencia circular con vpc.tf)
data "aws_prefix_list" "s3" {
  filter {
    name   = "prefix-list-name"
    values = ["com.amazonaws.${var.region}.s3"]
  }
}

locals {
  acct_suffix           = substr(data.aws_caller_identity.current.account_id, -6, -1)
  prefix                = "image-processor-${var.environment}"

  upload_bucket_name    = "${local.prefix}-uploads-${local.acct_suffix}"
  processed_bucket_name = "${local.prefix}-processed-${local.acct_suffix}"
  queue_name            = "${local.prefix}-queue"
  dlq_name              = "${local.prefix}-dlq"
  upload_fn_name        = "${local.prefix}-upload"
  crop_fn_name          = "${local.prefix}-crop"
  api_name              = "${local.prefix}-api"
  vpc_name              = "${local.prefix}-vpc"
}
