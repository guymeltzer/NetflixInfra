output "netflix_app_ami" {
  value = module.netflix_app.ami_id
}

output "ec2_public_ip" {
  value = module.netflix_app.instance_public_ip
}

output "ec2_instance_id" {
  value = module.netflix_app.instance_id
}

output "aws_s3_bucket_name" {
  value       = var.bucket_name
  description = "The name of the S3 Bucket in AWS"
}
