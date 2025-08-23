resource "aws_db_subnet_group" "this" {
  name       = "${var.tags.env}-rds-subnets"
  subnet_ids = var.private_subnet_ids
  tags       = var.tags
}

resource "aws_security_group" "rds" {
  name        = "rds-sg"
  description = "Allow MySQL from SG only"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = var.tags

}

resource "aws_security_group_rule" "mysql_from_app" {
  type                     = "ingress"
  security_group_id        = aws_security_group.rds.id
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = var.app_sg_id
}

resource "aws_db_instance" "this" {
  identifier              = "dev-mysql"
  engine                  = var.engine
  engine_version          = var.engine_version
  instance_class          = var.instance_class
  db_name                 = var.db_name
  username                = var.username
  password                = var.password
  allocated_storage       = var.allocated_storage
  storage_encrypted       = true
  skip_final_snapshot     = var.skip_final_snapshot
  vpc_security_group_ids  = [aws_security_group.rds.id]
  db_subnet_group_name    = aws_db_subnet_group.this.name
  publicly_accessible     = false
  backup_retention_period = 0
  deletion_protection     = false
  tags                    = var.tags

}
