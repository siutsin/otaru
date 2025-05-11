include {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_parent_terragrunt_dir()}//modules/aws-iam-irsa"
}

locals {
  oidc_vars = read_terragrunt_config(find_in_parent_folders("oidc.hcl")).locals

  name          = "jung2bot"
  oidc_provider = local.oidc_vars.oidc_provider
}

inputs = {
  name            = local.name
  oidc_provider   = local.oidc_provider
  service_account = "system:serviceaccount:${local.name}:jung2bot"
  role_policies = {
    dynamodb = {
      actions = ["dynamodb:*"]
      resources = [
        "arn:aws:dynamodb:*:*:table/${local.name}-chatIds",
        "arn:aws:dynamodb:*:*:table/${local.name}-messages",
        "arn:aws:dynamodb:*:*:table/${local.name}-chatIds/index/*",
        "arn:aws:dynamodb:*:*:table/${local.name}-messages/index/*",
      ]
    }
    dynamodb-generic = {
      actions = ["dynamodb:List*", "dynamodb:Describe*"]
      resources = ["*"]
    }
    sqs = {
      actions = ["sqs:*"]
      resources = [
        "arn:aws:sqs:*:*:${local.name}-event-queue",
      ]
    }
    sqs-generic = {
      actions = ["sqs:List*", "sqs:Describe*"]
      resources = ["*"]
    }
  }
}
