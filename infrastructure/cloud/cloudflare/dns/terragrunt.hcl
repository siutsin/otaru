include {
  path = find_in_parent_folders("root.hcl")
}

locals {
  zone             = get_env("CLOUDFLARE_ZONE")
  zone_id          = get_env("CLOUDFLARE_ZONE_ID")
  public_subdomain = get_env("CLOUDFLARE_ZONE_SUBDOMAIN")
}

dependencies {
  paths = ["../tunnel"]
}

dependency "tunnel" {
  config_path = "../tunnel"

  mock_outputs = {
    cname = "subdomain.example.com"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

terraform {
  source = "${get_parent_terragrunt_dir()}//modules/cloudflare-dns"
}

inputs = {
  zone    = local.zone
  zone_id = local.zone_id

  # public

  public_subdomain       = local.public_subdomain
  public_subdomain_value = dependency.tunnel.outputs.cname

  # private

  internal_records = {}
}
