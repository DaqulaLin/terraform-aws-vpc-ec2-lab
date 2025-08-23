variable "project" {
  type        = string
  description = "Project name (used for resource naming and tagging)"
}

variable "environment" {
  type        = string
  description = "environment identifier, such as dev/stage/prod"
}

variable "name_prefix" {
  type        = string
  description = "Prefix for resource names, typically in the format of project-environment"
}


variable "vpc_cidr" { type = string }
variable "azs" { type = list(string) }
variable "public_subnets" { type = list(string) }
variable "private_subnets" { type = list(string) }



variable "ec2_instance_type" { type = string }

variable "ami_id" {
  type    = string
  default = null
}

variable "rds_password" { type = string }




variable "enable_ec2" {
  type        = bool
  default     = false
  description = "Whether to create the single EC2"
}


variable "enable_alb" {
  type    = bool
  default = false
}

variable "enable_rds" {
  type    = bool
  default = false
}
