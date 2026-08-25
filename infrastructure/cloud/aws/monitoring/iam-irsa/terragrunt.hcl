include {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_parent_terragrunt_dir()}//modules/aws-iam-irsa"
}

locals {
  oidc_vars = read_terragrunt_config(find_in_parent_folders("oidc.hcl")).locals

  name          = "monitoring-yace"
  oidc_provider = local.oidc_vars.oidc_provider
}

inputs = {
  name            = local.name
  oidc_provider   = local.oidc_provider
  service_account = "system:serviceaccount:monitoring:monitoring-yace"
  role_policies = {
    cloudwatch = {
      actions   = ["cloudwatch:GetMetricStatistics"]
      resources = ["*"]
    }
  }
}
