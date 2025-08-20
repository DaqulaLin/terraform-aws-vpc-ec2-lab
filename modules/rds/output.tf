output "endpoint" { value = aws_db_instance.this.address }
output "rds_sg_id" { value = aws_security_group.rds.id }


output "db_arn" { value = aws_db_instance.this.arn }
output "db_subnet_group_name" { value = aws_db_subnet_group.this.name }
