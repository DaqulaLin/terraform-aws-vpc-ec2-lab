resource "aws_security_group" "alb" {
  name        = "app-alb-sg"
  description = "Allow HTTP from Internet to ALB"
  vpc_id      = var.vpc_id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = var.tags
}

resource "aws_lb" "this" {
  name               = "app-alb"
  load_balancer_type = "application"
  subnets            = var.public_subnet_ids
  security_groups    = [aws_security_group.alb.id]
  idle_timeout       = 60
  tags               = var.tags
}

resource "aws_lb_target_group" "this" {
  name        = "app-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance" # 单实例/ASG 都用 instance 类型
  health_check {
    path    = "/"
    matcher = "200-399"
  }
  tags = var.tags
}



resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

# 方式一：挂实例ID（按列表批量注册）
resource "aws_lb_target_group_attachment" "instances" {
  count            = length(var.target_instance_ids)
  target_group_arn = aws_lb_target_group.this.arn
  target_id        = var.target_instance_ids[count.index]
  port             = 80
}

# 方式二：挂 ASG（传入 asg_name 时启用）
/*
resource "aws_autoscaling_attachment" "asg" {
  count                  = var.asg_name == null ? 0 : 1
  autoscaling_group_name = var.asg_name
  lb_target_group_arn    = aws_lb_target_group.this.arn


}
*/
