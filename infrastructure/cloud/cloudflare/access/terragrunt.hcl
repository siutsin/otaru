include {
  path = find_in_parent_folders()
}

locals {
  zone      = get_env("CLOUDFLARE_ZONE")
  zone_id   = get_env("CLOUDFLARE_ZONE_ID")
  subdomain = get_env("CLOUDFLARE_ZONE_SUBDOMAIN")
  ip_list   = jsondecode(get_env("CLOUDFLARE_ZONE_TUNNEL_IP_LIST", "[]"))
}

terraform {
  source = "${get_parent_terragrunt_dir()}//modules/cloudflare-access"
}

inputs = {
  zone    = local.zone
  zone_id = local.zone_id
  name    = local.subdomain
  domain  = "${local.subdomain}.${local.zone}"
  ip_list = local.ip_list
}
