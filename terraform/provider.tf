terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.60" }
    tls = { source = "hashicorp/tls", version = "~> 4.0" }
    local = { source = "hashicorp/local", version = "~> 2.5" }
  }
  # Remote state (recommended). Create the bucket + lock table once, then uncomment:
  # backend "s3" {
  #   bucket         = "your-org-ecommerce-tfstate"
  #   key            = "ecommerce/terraform.tfstate"
  #   region         = "ap-south-1"
  #   dynamodb_table = "ecommerce-tflock"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = { Project = "ai-ecommerce-devops", Environment = var.environment, ManagedBy = "terraform" }
  }
}
