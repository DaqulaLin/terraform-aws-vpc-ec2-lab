project     = "tf-aws-infra"
environment = "dev"
region      = "us-east-1"
name_prefix = "tfaws-dev"

vpc_cidr        = "10.10.0.0/16"
azs             = ["us-east-1a", "us-east-1b"]
public_subnets  = ["10.10.1.0/24", "10.10.2.0/24"]
private_subnets = ["10.10.11.0/24", "10.10.12.0/24"]

ec2_instance_type = "t2.micro"
# ami_id = null  # 让数据源自动选 AL2023
