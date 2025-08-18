variable "region" {
  type = string
}

variable "ci_no_aws" {
  type    = bool
  default = false
}

provider "aws" {
  region                      = var.region
  skip_credentials_validation = var.ci_no_aws
  skip_requesting_account_id  = var.ci_no_aws
  skip_metadata_api_check     = var.ci_no_aws
  skip_region_validation      = var.ci_no_aws

}
