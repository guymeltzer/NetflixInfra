output "netflix_app_ami" {
  description = "ID of the EC2 instance AMI"
  value       = data.aws_ami.ubuntu_ami.id
}

output "ec2_public_ip" {
  value       = aws_instance.netflix_app.public_ip
  description = "The public IP of the EC2 instance"
}