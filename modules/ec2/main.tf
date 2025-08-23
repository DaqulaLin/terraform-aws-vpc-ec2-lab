# 若未传 ami_id，则选 Amazon Linux 2023（x86_64）
# If ami_id is not provided, select Amazon Linux 2023 (x86_64)
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["137112412989"] # Amazon
  filter {
    name   = "name"
    values = ["al2023-ami-2023*-kernel-6.1-x86_64"]
  }
}

locals {
  ami_id = coalesce(var.ami_id, data.aws_ami.al2023.id)
}


# SSM 角色与实例配置文件
# SSM role and instance profile configuration
resource "aws_iam_role" "ssm" {
  name = "${var.name_prefix}-ssm-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm" {
  name = "${var.name_prefix}-ssm-profile"
  role = aws_iam_role.ssm.name
}


# 开放 80/443；出站全通
# Open ports 80/443; allow all outbound traffic
resource "aws_security_group" "web" {
  name   = "${var.name_prefix}-web-sg"
  vpc_id = var.vpc_id

  /*
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  */
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

# 启动即安装 Nginx（AL2023 用 dnf）
# Install Nginx on startup (use dnf for AL2023) and ssm-agent
locals {
  user_data = <<-EOT
    #!/bin/bash
    dnf -y update
    dnf -y install nginx
    systemctl enable nginx
    echo "Hello from Nginx on $(hostname)" > /usr/share/nginx/html/index.html
    systemctl start nginx
    set -eux
    dnf install -y amazon-ssm-agent
    systemctl enable --now amazon-ssm-agent
  EOT
}

resource "aws_instance" "this" {
  ami                         = local.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ssm.name
  vpc_security_group_ids      = [aws_security_group.web.id]
  user_data                   = local.user_data
  tags                        = { Name = "${var.name_prefix}-web" }
}
