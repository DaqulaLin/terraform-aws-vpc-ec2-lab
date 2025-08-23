output "vpc_id" { value = module.vpc.vpc_id }
output "public_subnet_ids" { value = module.vpc.public_subnet_ids }
output "private_subnet_ids" { value = module.vpc.private_subnet_ids }
output "ec2_public_ip" { value = module.ec2.public_ip }


output "plan_role_arn" {
  value = module.iam_gha_oidc.plan_role_arn
}

output "apply_role_arn" {
  value = module.iam_gha_oidc.apply_role_arn
}

output "alb_dns_name" {
  value       = var.enable_alb ? module.alb["main"].alb_dns_name : null
  description = "ALB DNS name when enabled"

}


output "alb_sg_id" {
  value       = var.enable_alb ? module.alb["main"].alb_sg_id : null
  description = "ALB security group id when enabled"
}

# envs/dev/outputs.tf
output "rds_endpoint" {
  value       = var.enable_rds ? module.rds["main"].endpoint : null
  description = "RDS endpoint when enabled"
}


#output "rds_endpoint" { value = module.rds.endpoint }
