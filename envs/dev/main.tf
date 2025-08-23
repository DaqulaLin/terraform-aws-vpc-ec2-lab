
module "vpc" {
  for_each        = local.vpc_enabled
  source          = "../../modules/vpc"
  name_prefix     = var.name_prefix
  vpc_cidr        = var.vpc_cidr
  azs             = var.azs
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets


}


module "iam_gha_oidc" {
  source                = "../../modules/iam"
  github_org            = "DaqulaLin"
  github_repo           = "terraform-aws-vpc-ec2-lab"
  region                = var.region
  state_bucket_name     = "my-terraform-state-daqula"
  state_lock_table_name = "tf-locks"


}



module "ec2" {
  for_each      = local.ec2_enabled
  source        = "../../modules/ec2"
  name_prefix   = var.name_prefix
  subnet_id     = module.vpc["main"].public_subnet_ids[0]
  vpc_id        = module.vpc["main"].vpc_id
  instance_type = var.ec2_instance_type
  ami_id        = var.ami_id

}



module "alb" {
  for_each          = local.alb_enabled
  source            = "../../modules/alb"
  vpc_id            = module.vpc["main"].vpc_id
  public_subnet_ids = module.vpc["main"].public_subnet_ids

  # 当前阶段：用实例ID列表对接
  target_instance_ids = var.enable_ec2 ? module.ec2["main"].instance_ids : []

  # 未来切到 ASG 时：把上面这一行删掉/注释掉，并传 asg_name
  # asg_name          = module.asg.name

  tags = { env = "dev", app = "demo" }
}


# 让 EC2 只接受来自 ALB 的 80 端口（如 EC2 模块未内置规则，则在此补一条）

resource "aws_security_group_rule" "web_from_alb" {
  count                    = (var.enable_vpc && var.enable_alb && var.enable_ec2) ? 1 : 0
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = module.ec2["main"].security_group_id # 目标：EC2 SG（由 EC2 子模块输出）
  source_security_group_id = module.alb["main"].alb_sg_id         # 源：ALB SG（由 ALB 子模块输出）
}



module "rds" {
  for_each           = local.rds_enabled
  source             = "../../modules/rds"
  vpc_id             = module.vpc["main"].vpc_id
  private_subnet_ids = module.vpc["main"].private_subnet_ids
  app_sg_id          = module.ec2["main"].security_group_id
  password           = var.rds_password
  tags               = { env = "dev", app = "demo" }
}
