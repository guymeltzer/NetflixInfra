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

module "netflix_app_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"

  name = "guy-netflix-vpc"
  cidr = "10.0.0.0/16"

  azs             = data.aws_availability_zones.available_azs.names
  private_subnets = ["10.0.0.0/28", "10.0.0.32/28"]
  public_subnets  = ["10.0.1.0/28", "10.0.2.0/28"]

  enable_nat_gateway = true


  tags = {
    Env = var.env
  }
}

provider "aws" {
  region = var.region
}

data "aws_availability_zones" "available_azs" {
  state = "available"
}

resource "aws_key_pair" "netflix_key" {
  key_name   = "netflix_key"        # Name of the key pair
  public_key = file("./id_rsa.pub") # Path to the public key file
}

data "aws_ami" "ubuntu_ami" {
  most_recent = true
  owners      = ["099720109477"]  # Canonical owner ID for Ubuntu AMIs

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

resource "aws_instance" "netflix_app" {
  ami                    = data.aws_ami.ubuntu_ami.id
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.netflix_key.key_name
  user_data              = file("./deploy.sh")
  vpc_security_group_ids = [aws_security_group.netflix_app_sg.id]
  subnet_id              = module.netflix_app_vpc.public_subnets[0]
  associate_public_ip_address = true  # Add this line

  tags = {
    Name      = "guy-netflix-infra-tfstate-${var.env}"
    Terraform = "Owned"
    Env       = var.env
  }
}

resource "aws_security_group" "netflix_app_sg" {
  name        = "guy-netflix-stack-sg"
  description = "Allow SSH and HTTP traffic"
  vpc_id      = module.netflix_app_vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3001
    to_port     = 3001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ebs_volume" "netflix_data" {
  availability_zone = aws_instance.netflix_app.availability_zone
  size              = 5
  tags = {
    Name = "NetflixData"
  }
}

resource "aws_iam_role" "netflix_app_role" {
  name = "guy-tff-role"
  assume_role_policy = jsonencode({
    "Version" = "2012-10-17",
    "Statement" = [
      {
        "Effect" = "Allow",
        "Principal" = {
          "Service" = "ec2.amazonaws.com"
        },
        "Action" = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_volume_attachment" "netflix_data_attach" {
  device_name = "/dev/xvdf"
  volume_id   = aws_ebs_volume.netflix_data.id
  instance_id = aws_instance.netflix_app.id
}


