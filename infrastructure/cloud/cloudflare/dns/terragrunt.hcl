include {
  path = find_in_parent_folders("root.hcl")
}

locals {
  tfconfig   = jsondecode(file(get_env("OTARU_TF_CONFIG_FILE")))
  zone_id    = local.tfconfig.cloudflare.zone.id
  default_ip = local.tfconfig.cloudflare.zone.dns_ip
  # Hostname strings use zone dns_ip. Object form may set ip.
  subdomains = {
    for key, value in local.tfconfig.cloudflare.dns : key => {
      name = try(value.name, value)
      ip   = try(value.ip, local.default_ip)
    }
  }
}

terraform {
  source = "${get_parent_terragrunt_dir()}//modules/cloudflare-internal-dns"
}

inputs = {
  zone_id    = local.zone_id
  subdomains = local.subdomains
}
