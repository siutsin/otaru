include {
  path = find_in_parent_folders()
}

locals {
  project_vars = read_terragrunt_config(find_in_parent_folders("project.hcl")).locals

  domain    = get_env("CLOUDFLARE_ZONE")
  subdomain = get_env("CLOUDFLARE_ZONE_SUBDOMAIN")
}

terraform {
  source = "${get_parent_terragrunt_dir()}//modules/aws-route53-health-check"
}

inputs = {
  health_check_fqdn = "${local.subdomain}.${local.domain}"
  name              = local.project_vars.name
}
