variable "env" {
  description = "Deployment environment"
  type        = string
}

variable "aws_region" {  # Changed to match the main project
  description = "AWS region"
  type        = string
}

variable "ami_id" {
  description = "EC2 Ubuntu AMI"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID"
  type        = string
}

variable "subnet_cidr" {
  description = "Subnet CIDR"
  type        = list(string)
}

variable "vpc_cidr" {
  description = "CIDR block for the VPN subnet"
  type        = string
}

variable "instance_type" {
  description = "Instance Type of EC2 instance"
  type        = string
}

variable "bucket_name" {
  description = "S3 bucket name"
  type        = string
}
