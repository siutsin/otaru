include {
  path = find_in_parent_folders("root.hcl")
}

locals {
  tfconfig   = jsondecode(file(get_env("OTARU_TF_CONFIG_FILE")))
  zone_id    = local.tfconfig.cloudflare.zone.id
  subdomains = local.tfconfig.cloudflare.dns
  ip         = local.tfconfig.cloudflare.zone.dns_ip
}

terraform {
  source = "${get_parent_terragrunt_dir()}//modules/cloudflare-internal-dns"
}

inputs = {
  zone_id    = local.zone_id
  subdomains = local.subdomains
  ip         = local.ip
}
