include {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_parent_terragrunt_dir()}//modules/aws-iam-irsa"
}

locals {
  oidc_vars = read_terragrunt_config(find_in_parent_folders("oidc.hcl")).locals

  name          = "keda"
  oidc_provider = local.oidc_vars.oidc_provider
}

inputs = {
  name            = local.name
  oidc_provider   = local.oidc_provider
  service_account = "system:serviceaccount:keda:keda-operator"
  role_policies = {
    sqs = {
      actions = ["sqs:GetQueueAttributes"]
      resources = [
        "arn:aws:sqs:*:*:jung2bot-prod-event-queue",
        "arn:aws:sqs:*:*:jung2bot-dev-event-queue",
      ]
    }
  }
}
