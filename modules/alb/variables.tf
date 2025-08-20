variable "vpc_id" { type = string }
variable "public_subnet_ids" { type = list(string) }

# 方式一：直接挂实例ID（当前用）
variable "target_instance_ids" {
  type        = list(string)
  default     = []
  description = "EC2 instance IDs to register to target group"
}

# 方式二：挂 ASG（未来切换用）
variable "asg_name" {
  type        = string
  default     = null
  description = "Autoscaling group name to attach to target group"
}

variable "tags" {
  type    = map(string)
  default = {}
}
