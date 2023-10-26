include {
  path = find_in_parent_folders()
}

locals {
  domain    = get_env("CLOUDFLARE_ZONE")
  subdomain = get_env("CLOUDFLARE_ZONE_SUBDOMAIN")
  path      = "/httpbin/status/200"
}

terraform {
  source = "${get_parent_terragrunt_dir()}//modules/uptime-robot"
}

inputs = {
  monitor_url = "https://${local.subdomain}.${local.domain}${local.path}"
}
