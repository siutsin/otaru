include {
  path = find_in_parent_folders("root.hcl")
}

locals {
  tfconfig = jsondecode(file(get_env("OTARU_TF_CONFIG_FILE")))
}

terraform {
  source = "${get_parent_terragrunt_dir()}//modules/cloudflare-workers-ai"
}

inputs = {
  account_id = local.tfconfig.cloudflare.account.id
  token_id   = local.tfconfig.cloudflare.workers_ai.token_id
}
