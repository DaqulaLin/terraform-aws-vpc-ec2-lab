terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {

  ec2_instance_ids = [module.ec2.instance_id]

  # EC2 的安全组ID：兼容不同模块的输出名
  ec2_sg_id = module.ec2.security_group_id
}



module "vpc" {
  source          = "../../modules/vpc"
  name_prefix     = var.name_prefix
  vpc_cidr        = var.vpc_cidr
  azs             = var.azs
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets
}


module "ec2" {
  source        = "../../modules/ec2"
  name_prefix   = var.name_prefix
  subnet_id     = module.vpc.public_subnet_ids[0]
  vpc_id        = module.vpc.vpc_id
  instance_type = var.ec2_instance_type
  ami_id        = var.ami_id
}


module "iam_gha_oidc" {
  source                = "../../modules/iam"
  github_org            = "DaqulaLin"
  github_repo           = "terraform-aws-vpc-ec2-lab"
  region                = var.region
  state_bucket_name     = "tfstate-160885250897-dev-1833551180"
  state_lock_table_name = "tf-locks"
}

module "alb" {
  source              = "../../modules/alb"
  vpc_id              = module.vpc.vpc_id
  public_subnet_ids   = module.vpc.public_subnet_ids
  target_instance_ids = local.ec2_sg_id
  tags                = { env = "dev", app = "demo" }
}

# 让 EC2 只接受来自 ALB 的 80 端口（如 EC2 模块未内置规则，则在此补一条）
resource "aws_security_group_rule" "web_from_alb" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = local.ec2_sg_id
  source_security_group_id = module.alb.alb_sg_id
}

module "rds" {
  source             = "../../modules/rds"
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  app_sg_id          = local.ec2_sg_id
  password           = var.rds_password
  tags               = { env = "dev", app = "demo" }
}
