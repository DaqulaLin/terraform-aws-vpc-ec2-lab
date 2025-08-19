provider "aws" { region = var.region }



# 1) GitHub OIDC Provider（thumbprint 作兜底；AWS 现已托管更新）
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da2b0ab7280"]
}

locals { gh_repo = "${var.github_org}/${var.github_repo}" }



# 2) 只读 plan 角色（PR 使用）
data "aws_iam_policy_document" "assume_plan" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${local.gh_repo}:pull_request"]
    }
  }
}

resource "aws_iam_role" "tf_plan" {
  name                 = "gha-oidc-tf-plan"
  assume_role_policy   = data.aws_iam_policy_document.assume_plan.json
  max_session_duration = 3600
}


# PR 只需读远程 state（plan 用 -lock=false，不授锁表权限）
data "aws_iam_policy_document" "plan_policy" {
  statement {
    sid     = "S3StateRead"
    effect  = "Allow"
    actions = ["s3:ListBucket", "s3:GetObject", "s3:GetObjectVersion"]
    resources = [
      "arn:aws:s3:::${var.state_bucket_name}",
      "arn:aws:s3:::${var.state_bucket_name}/*"
    ]
  }
  statement {
    sid    = "EC2Describe"
    effect = "Allow"
    actions = [
      "ec2:DescribeImages",
      "ec2:DescribeInstances",
      "ec2:DescribeVpcs",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "tf_plan" {
  name   = "tf-plan-read-state"
  policy = data.aws_iam_policy_document.plan_policy.json
}

resource "aws_iam_role_policy_attachment" "tf_plan_attach" {
  role       = aws_iam_role.tf_plan.name
  policy_arn = aws_iam_policy.tf_plan.arn
}


# 3) apply 角色（main 使用）——先给管理员
data "aws_iam_policy_document" "assume_apply" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${local.gh_repo}:ref:refs/heads/main"]
    }
  }
}

resource "aws_iam_role" "tf_apply" {
  name                 = "gha-oidc-tf-apply"
  assume_role_policy   = data.aws_iam_policy_document.assume_apply.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "tf_apply_admin" {
  role       = aws_iam_role.tf_apply.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}