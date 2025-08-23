locals {
  ec2_enabled = var.enable_ec2 ? { main = true } : {}
  alb_enabled = var.enable_alb ? { main = true } : {}
  rds_enabled = (var.enable_rds && var.enable_ec2) ? { main = true } : {}
}
