variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "app_sg_id" { type = string } # 仅允许应用SG访问

variable "engine" {
  type    = string
  default = "mysql"
}

variable "engine_version" {
  type    = string
  default = "8.0"

} # MySQL 8

variable "instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "db_name" {
  type        = string
  default     = "appdb"
  description = "The name of the database to create when the DB instance is created."
}

variable "allocated_storage" {
  type    = number
  default = 20
}

variable "username" {
  type    = string
  default = "appuser"
}

variable "password" {
  type      = string
  sensitive = true
} # dev 用 tfvars；生产迁 Secret

variable "skip_final_snapshot" {
  type    = bool
  default = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
