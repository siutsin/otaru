include {
  path = find_in_parent_folders("root.hcl")
}

locals {
  zone_id       = get_env("CLOUDFLARE_ZONE_ID")
  zone          = get_env("CLOUDFLARE_ZONE")
  account_id    = get_env("CLOUDFLARE_ACCOUNT_ID")
  name          = get_env("CLOUDFLARE_ZONE_SUBDOMAIN")
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
  network_cidr    = "192.168.1.0/24"
  gateway_service = "http://cilium-gateway-ingress.cilium-gateway.svc.cluster.local"
}
