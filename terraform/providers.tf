terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Optional: remote state (recommended for team use)
  # backend "s3" {
  #   bucket = "your-terraform-state-bucket"
  #   key    = "monitoring/terraform.tfstate"
  #   region = "us-east-1"
  # }
}

provider "aws" {
  region = var.aws_region
}
