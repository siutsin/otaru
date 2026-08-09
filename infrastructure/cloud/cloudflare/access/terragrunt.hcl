include {
  path = find_in_parent_folders("root.hcl")
}

locals {
  tfconfig   = jsondecode(file(get_env("OTARU_TF_CONFIG_FILE")))
  account_id = local.tfconfig.cloudflare.account.id
  zone       = local.tfconfig.cloudflare.zone.hostname
  zone_id    = local.tfconfig.cloudflare.zone.id
  subdomain  = local.tfconfig.cloudflare.zone.subdomain
  ip_list    = local.tfconfig.cloudflare.zone.tunnel_ip_list
}

terraform {
  source = "${get_parent_terragrunt_dir()}//modules/cloudflare-access"
}

inputs = {
  account_id = local.account_id
  zone       = local.zone
  zone_id    = local.zone_id
  name       = local.subdomain
  domain     = "${local.subdomain}.${local.zone}"
  ip_list    = local.ip_list
}
