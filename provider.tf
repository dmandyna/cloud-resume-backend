terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.2.0"
    }
  }

  backend "s3" {
    bucket = "dmandyna-tf-backend-eu-west-1"
    key    = "projects/cloud-resume/backend.tf"
    region = "eu-west-1"
  }
}

provider "aws" {
  region = "eu-west-1"
  default_tags {
    tags = {
      managed_by = "terraform"
      project    = "CloudResume"
    }
  }
}
