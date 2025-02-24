output "netflix_app_ami" {
  description = "ID of the EC2 instance AMI"
  value       = data.aws_ami.ubuntu_ami.id
}

output "ec2_public_ip" {
  value       = aws_instance.netflix_app.public_ip
  description = "The public IP of the EC2 instance"
}

output "ec2_instance_id" {
  value       = aws_instance.netflix_app.id
  description = "The Instance ID of the EC2 instance"
}

output "aws_s3_bucket_name" {
  value       = var.bucket_name
  description = "The name of the S3 Bucket in AWS"
}

