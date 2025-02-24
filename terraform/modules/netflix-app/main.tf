resource "aws_key_pair" "netflix_key" {
  key_name   = "netflix_key"
  public_key = file("./id_rsa.pub")
}

provider "aws" {
  region = var.aws_region
}

data "aws_ami" "ubuntu_ami" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

resource "aws_iam_role" "netflix_app_role" {
  name = "guy-tff-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "netflix_app_policy" {
  name        = "guy-netflix-app-policy"
  description = "Policy for EC2 Netflix application to access AWS services"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["s3:ListBucket", "s3:GetObject", "s3:PutObject"],
        Resource = ["arn:aws:s3:::guy-netflix-*", "arn:aws:s3:::guy-netflix-*/*"]
      },
      {
        Effect   = "Allow",
        Action   = ["ec2:DescribeInstances", "ec2:DescribeVolumes"],
        Resource = "*"
      },
      {
        Effect   = "Allow",
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"],
        Resource = "arn:aws:logs:${var.region}:352708296901:*"
      },
      {
        Effect   = "Allow",
        Action   = ["ssm:GetParameter", "ssm:PutParameter"],
        Resource = "arn:aws:ssm:${var.region}:352708296901:parameter/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "netflix_app_role_attachment" {
  role       = aws_iam_role.netflix_app_role.name
  policy_arn = aws_iam_policy.netflix_app_policy.arn
}

resource "aws_iam_instance_profile" "netflix_app_profile" {
  name = "netflix-instance-profile"
  role = aws_iam_role.netflix_app_role.name
}

resource "aws_instance" "netflix_app" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.netflix_key.key_name
  user_data                   = file("./deploy.sh")
  vpc_security_group_ids      = [aws_security_group.netflix_app_sg.id]
  subnet_id                   = var.subnet_id
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.netflix_app_profile.name
  subnet_cidr                 = var.subnet_cidr
  aws_region                  = var.aws_region
  vpc_cidr                    = var.vpc_cidr
  bucket_name                 = var.bucket_name

  tags = {
    Name      = "guy-netflix-${var.env}"
    Terraform = "Owned"
    Env       = var.env
  }
}

resource "aws_subnet" "subnet" {
  count = length(var.subnet_cidr)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_cidr[count.index]
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = true

resource "aws_security_group" "netflix_app_sg" {
  name        = "guy-netflix-stack-sg"
  description = "Allow SSH and HTTP traffic"
  vpc_id      = var.vpc_id

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

resource "aws_volume_attachment" "netflix_data_attach" {
  device_name = "/dev/xvdf"
  volume_id   = aws_ebs_volume.netflix_data.id
  instance_id = aws_instance.netflix_app.id
}
