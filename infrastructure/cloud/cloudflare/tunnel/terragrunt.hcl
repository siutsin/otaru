include {
  path = find_in_parent_folders("root.hcl")
}

locals {
  account_id = get_env("CLOUDFLARE_ACCOUNT_ID")
  name       = get_env("CLOUDFLARE_ZONE_SUBDOMAIN")
  secret     = get_env("CLOUDFLARE_TUNNEL_SECRET")
}

terraform {
  source = "${get_parent_terragrunt_dir()}//modules/cloudflare-tunnel"
}

inputs = {
  account_id = local.account_id
  name       = local.name
  secret     = local.secret
}
