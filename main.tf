terraform {
  required_version = ">= 1.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }

  backend "s3" {
    bucket         = "hf-ml-platform-tfstate"
    key            = "rds/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "hf-ml-platform-tfstate-lock"
  }
}

provider "aws" {
  region = var.region
}
