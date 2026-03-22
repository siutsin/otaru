include {
  path = find_in_parent_folders("root.hcl")
}

locals {
  zone_id    = get_env("CLOUDFLARE_ZONE_ID")
  subdomains = jsondecode(get_env("CLOUDFLARE_DNS_SUBDOMAINS"))
  ip         = get_env("CLOUDFLARE_DNS_IP")
}

terraform {
  source = "${get_parent_terragrunt_dir()}//modules/cloudflare-internal-dns"
}

inputs = {
  zone_id    = local.zone_id
  subdomains = local.subdomains
  ip         = local.ip
}
