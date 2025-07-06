locals {
  oidc_provider_without_https = replace(var.oidc_provider, "https://", "")
  identifiers                 = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${local.oidc_provider_without_https}"]
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = local.identifiers
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_without_https}:aud"
      values   = [local.oidc_provider_without_https]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider_without_https}:sub"
      values   = [var.service_account]
    }
  }
}

data "aws_iam_policy_document" "role" {
  dynamic "statement" {
    for_each = var.role_policies
    content {
      actions   = statement.value.actions
      resources = statement.value.resources
    }
  }
}

resource "aws_iam_role_policy" "role" {
  name   = var.name
  role   = aws_iam_role.role.id
  policy = data.aws_iam_policy_document.role.json
}

resource "aws_iam_role" "role" {
  name               = var.name
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}
