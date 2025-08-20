plugin "aws" {
  enabled = true
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
  version = "0.42.0"
}

config {
  call_module_type = "all" # 新语法，替代 module = true

}
