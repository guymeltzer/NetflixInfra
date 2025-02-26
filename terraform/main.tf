terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">=5.55"
    }
  }

  required_version = ">= 1.7.0"

  backend "s3" {
    bucket = "guy-netflix-infra-tfstate"
    key    = "tfstate.json"
    region = "eu-north-1"
  }
}

provider "aws" {
  region = var.region
}

module "netflix_app_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"

  name = "guy-netflix-vpc"
  cidr = var.vpc_cidr

  azs             = data.aws_availability_zones.available_azs.names
  private_subnets = [var.subnet_cidr[0], var.subnet_cidr[1]]
  public_subnets  = [var.subnet_cidr[2], var.subnet_cidr[3]]

  enable_nat_gateway = true

  tags = {
    Env = var.env
  }
}

data "aws_availability_zones" "available_azs" {
  state = "available"
}

module "netflix_app" {
  source = "./modules/netflix-app"
  public_key_path = var.public_key_path
  env           = var.env
  aws_region    = var.region
  vpc_id        = module.netflix_app_vpc.vpc_id
  subnet_id     = module.netflix_app_vpc.public_subnets[0]
  instance_type = var.instance_type
  bucket_name   = var.bucket_name
}
