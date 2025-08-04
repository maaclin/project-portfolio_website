

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  backend "s3" {
    bucket       = "ysolomprojects-tfstate"
    key          = "terraform"
    region       = "eu-west-2"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = "eu-west-2"
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}