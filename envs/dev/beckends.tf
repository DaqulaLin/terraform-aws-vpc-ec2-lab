terraform {
  required_version = ">= 1.6.0"
  backend "s3" {
    bucket         = "tfstate-160885250897-dev-1833551180"
    dynamodb_table = "tf-locks"
    key            = "project1/envs/dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
