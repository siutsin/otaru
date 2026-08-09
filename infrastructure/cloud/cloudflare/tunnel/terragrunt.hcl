include {
  path = find_in_parent_folders("root.hcl")
}

locals {
  tfconfig      = jsondecode(file(get_env("OTARU_TF_CONFIG_FILE")))
  zone_id       = local.tfconfig.cloudflare.zone.id
  zone          = local.tfconfig.cloudflare.zone.hostname
  account_id    = local.tfconfig.cloudflare.account.id
  name          = local.tfconfig.cloudflare.zone.subdomain
  tunnel_secret = get_env("CLOUDFLARE_TUNNEL_SECRET")
}

terraform {
  source = "${get_parent_terragrunt_dir()}//modules/cloudflare-tunnel"
}

inputs = {
  zone_id         = local.zone_id
  zone            = local.zone
  account_id      = local.account_id
  name            = local.name
  config_src      = "cloudflare"
  tunnel_secret   = local.tunnel_secret
  network_cidr    = "192.168.10.0/24"
  gateway_service = "https://gateway.gateway.svc.cluster.local"
}
