variable "name_prefix" { type = string }

variable "subnet_id" { type = string } # 放在一个公有子网

variable "vpc_id" { type = string }

variable "instance_type" { type = string }

variable "ami_id" {
  type    = string
  default = null
}
