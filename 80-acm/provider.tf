terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.66.0"
    }
  }

  backend "s3" {
    bucket         = "81s-remote-state-bucket-dev"
    key            = "expense-dev-acm" # a repo sould have unique s3 key 
    region         = "us-east-1"
    dynamodb_table = "81s-locking-dev"

  }
}

provider "aws" {
  # Configuration options
  region = "us-east-1"
}


