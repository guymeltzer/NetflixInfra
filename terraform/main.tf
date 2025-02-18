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

data "aws_secretsmanager_secret" "aws_credentials" {
  name = "aws-credentials"
}

data "aws_secretsmanager_secret_version" "aws_credentials" {
  secret_id = data.aws_secretsmanager_secret.aws_credentials.id
}

provider "aws" {
  region = var.region
  access_key = jsondecode(data.aws_secretsmanager_secret_version.aws_credentials.secret_string)["AWS_ACCESS_KEY_ID"]
  secret_key = jsondecode(data.aws_secretsmanager_secret_version.aws_credentials.secret_string)["AWS_SECRET_ACCESS_KEY"]
}

resource "aws_key_pair" "netflix_key" {
  key_name   = "id_rsa"
  public_key = file("/home/guy/.ssh/id_rsa.pub")
}

resource "aws_instance" "netflix_app" {
  ami             = var.ami_id
  instance_type   = "t3.micro"
  key_name        = aws_key_pair.netflix_key.key_name
  user_data       = file("./deploy.sh")
  security_groups = [aws_security_group.netflix_app_sg.name]

  tags = {
    Name      = "guy-netflix-infra-tfstate${var.env}"
    Terraform = "Owned"
    Env       = var.env
  }
}

resource "aws_security_group" "netflix_app_sg" {
  name        = "guy-netflix-app-sg"
  description = "Allow SSH and HTTP traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
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
