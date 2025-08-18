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
