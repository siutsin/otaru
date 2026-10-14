include {
  path = find_in_parent_folders("root.hcl")
}

locals {
  tfconfig = jsondecode(file(get_env("OTARU_TF_CONFIG_FILE")))
}

terraform {
  source = "${get_parent_terragrunt_dir()}//modules/cloudflare-chart-cache"
}

inputs = {
  account_id = local.tfconfig.cloudflare.account.id
  zone_id    = local.tfconfig.cloudflare.zone.id
}
