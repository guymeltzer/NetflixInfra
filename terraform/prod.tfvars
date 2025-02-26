env    = "prod"
region = "eu-north-1"
vpc_cidr = "10.0.0.0/16"
instance_type = "t3.micro"
bucket_name = "guy-netflix-infra-tfstate"
public_key_path = "/home/guy/.ssh/id_rsa.pub"
subnet_cidr = ["10.0.0.0/28", "10.0.0.32/28", "10.0.1.0/28", "10.0.2.0/28"]
