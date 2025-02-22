output "netflix_app_ami" {
  description = "ID of the EC2 instance AMI"
  value       = data.aws_ami.ubuntu_ami.id
}
