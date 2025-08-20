output "public_ip" { value = aws_instance.this.public_ip }
output "public_dns" { value = aws_instance.this.public_dns }
output "instance_id" {
  value = aws_instance.this.id
}

output "security_group_id" {
  value = aws_security_group.web.id
}

output "instance_ids" {

  value = [aws_instance.this.id]
}

# 顺手也把 EC2 安全组导出来，给外层加 ALB -> EC2 的放行规则用
output "web_sg_id" {
  value = aws_security_group.web.id
}
