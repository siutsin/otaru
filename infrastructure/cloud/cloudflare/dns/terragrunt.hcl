include {
  path = find_in_parent_folders()
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

  records = {

    # A

    adguard_internal = {
      name    = "adguard.internal"
      value   = "192.168.1.51"
      type    = "A"
      ttl     = 1
      proxied = false
    },

    argocd_internal = {
      name    = "argocd.internal"
      value   = "192.168.1.51"
      type    = "A"
      ttl     = 1
      proxied = false
    },

    kiali_internal = {
      name    = "kiali.internal"
      value   = "192.168.1.51"
      type    = "A"
      ttl     = 1
      proxied = false
    },

    kubernetes_dashboard_internal = {
      name    = "kubernetes-dashboard.internal"
      value   = "192.168.1.51"
      type    = "A"
      ttl     = 1
      proxied = false
    },

    longhorn_internal = {
      name    = "longhorn.internal"
      value   = "192.168.1.51"
      type    = "A"
      ttl     = 1
      proxied = false
    },

    # CNAME

    home_lab = {
      name    = local.public_subdomain
      value   = dependency.tunnel.outputs.cname
      type    = "CNAME"
      ttl     = 1
      proxied = true
    },
  }
}
