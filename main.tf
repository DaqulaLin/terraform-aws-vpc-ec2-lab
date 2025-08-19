module "vpc" {
  source          = "./modules/vpc"
  name_prefix     = var.name_prefix
  vpc_cidr        = var.vpc_cidr
  azs             = var.azs
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets
}


module "ec2" {
  source        = "./modules/ec2"
  name_prefix   = var.name_prefix
  subnet_id     = module.vpc.public_subnet_ids[0]
  vpc_id        = module.vpc.vpc_id
  instance_type = var.ec2_instance_type
  ami_id        = var.ami_id
}


module "iam_gha_oidc" {
  source            = "./modules/iam"
  github_org        = "DaqulaLin"
  github_repo       = "terraform-aws-vpc-ec2-lab"
  region            = var.region
  state_bucket_name = "tfstate-160885250897-dev-1833551180"
  lock_table_name   = "tf-locks"
}
