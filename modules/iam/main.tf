
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
    actions = ["s3:ListBucket", "s3:GetBucketLocation", "s3:GetObject", "s3:GetObjectVersion"]
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
      "ec2:DescribeRouteTables",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeNatGateways",
      "ec2:DescribeSecurityGroups"
    ]
    resources = ["*"]
  }
  # 仅用于 plan 的读取权限（不会创建/修改）
  statement {
    sid       = "IAMReadOnly"
    effect    = "Allow"
    actions   = ["iam:Get*", "iam:List*"]
    resources = ["*"]
  }
  statement {
    sid       = "EC2ReadOnly"
    effect    = "Allow"
    actions   = ["ec2:Describe*"]
    resources = ["*"]
  }
  statement {
    sid       = "ELBReadOnly"
    effect    = "Allow"
    actions   = ["elasticloadbalancing:Describe*"]
    resources = ["*"]
  }
  # 若后续 PR 会读 ASG/RDS，也一并加：
  statement {
    sid       = "ASGReadOnly"
    effect    = "Allow"
    actions   = ["autoscaling:Describe*"]
    resources = ["*"]
  }
  statement {
    sid    = "RDSReadOnly"
    effect = "Allow"
    actions = ["rds:Describe*",
      "rds:ListTagsForResource"
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
      values = ["repo:${local.gh_repo}:ref:refs/heads/main",
        "repo:${local.gh_repo}:environment:prod"
        # 如未来用 tag 发布，也可顺带放开：
        # "repo:${local.gh_repo}:ref:refs/tags/*"
      ]

    }
  }
}

resource "aws_iam_role" "tf_apply" {
  name                 = "gha-oidc-tf-apply"
  assume_role_policy   = data.aws_iam_policy_document.assume_apply.json
  max_session_duration = 3600
}

data "aws_caller_identity" "current" {}

# --- MVP 应用权限：远程状态 + EC2/ELB/RDS 服务范围 ---
data "aws_iam_policy_document" "apply_policy_mvp" {
  # S3 远程状态：读写对象 + 列目录
  statement {
    sid    = "S3StateRW"
    effect = "Allow"
    actions = [
      "s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:GetObjectVersion",
      "s3:ListBucket", "s3:GetBucketLocation"
    ]
    resources = [
      "arn:aws:s3:::${var.state_bucket_name}",
      "arn:aws:s3:::${var.state_bucket_name}/*"
    ]
  }
  # DynamoDB 锁表：加/读/删/改锁
  statement {
    sid    = "DDBLockRW"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem", "dynamodb:PutItem",
      "dynamodb:DeleteItem", "dynamodb:UpdateItem"
    ]
    resources = [
      "arn:aws:dynamodb:${var.region}:${data.aws_caller_identity.current.account_id}:table/${var.state_lock_table_name}"
    ]
  }

  # 业务服务（MVP：先放到服务级，跑通后再逐步收敛到资源 ARN）
  statement {
    sid    = "ProjectServices"
    effect = "Allow"
    actions = [
      "ec2:*",
      "vpc:*",
      "elasticloadbalancing:*",
      "rds:*",
      # 如你的模块里有创建/绑定 Instance Profile 或 Log Group，可保留以下几类：
      "iam:Get*",
      "iam:List*",
      "iam:PassRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicyVersion",
      "logs:*", "cloudwatch:*"
    ]
    resources = ["*"]
  }
  # 如你的 tfstate 桶使用了 SSE-KMS，加上 KMS 基本权限（否则读写对象会因 KMS 报错）
  # 把 <KMS_KEY_ARN> 改成你状态桶用的 KMS Key ARN；没有就删掉这个 statement。
  # statement {
  #   sid     = "StateKMS"
  #   effect  = "Allow"
  #   actions = ["kms:Decrypt","kms:Encrypt","kms:GenerateDataKey*","kms:DescribeKey"]
  #   resources = ["<KMS_KEY_ARN>"]
  # }
}

resource "aws_iam_policy" "tf_apply_mvp" {
  name   = "gha-apply-mvp"
  policy = data.aws_iam_policy_document.apply_policy_mvp.json
}

resource "aws_iam_role_policy_attachment" "tf_apply_attach_mvp" {
  role       = aws_iam_role.tf_apply.name
  policy_arn = aws_iam_policy.tf_apply_mvp.arn
}

/*
resource "aws_iam_role_policy_attachment" "tf_apply_admin" {
  role       = aws_iam_role.tf_apply.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
*/
