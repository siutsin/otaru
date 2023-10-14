include {
  path = find_in_parent_folders()
}

locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))

  zone      = local.account_vars.locals.cloudflare_zone
  subdomain = local.account_vars.locals.cloudflare_zone_subdomain
  ip_list   = local.account_vars.locals.cloudflare_zone_tunnel_ip_list
}

terraform {
  source = "${get_parent_terragrunt_dir()}/..//modules/cloudflare-access"
}

inputs = {
  zone    = local.zone
  name    = local.subdomain
  domain  = "${local.subdomain}.${local.zone}"
  ip_list = local.ip_list
}
