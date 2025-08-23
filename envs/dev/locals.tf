locals {
  vpc_enabled = var.enable_vpc ? { main = true } : {}
  ec2_enabled = (var.enable_vpc && var.enable_ec2) ? { main = true } : {}
  alb_enabled = (var.enable_vpc && var.enable_alb) ? { main = true } : {}
  rds_enabled = (var.enable_rds && var.enable_ec2) ? { main = true } : {}
}
