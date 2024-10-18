include {
  path = find_in_parent_folders()
}

locals {
  zone             = get_env("CLOUDFLARE_ZONE")
  zone_id          = get_env("CLOUDFLARE_ZONE_ID")
  public_subdomain = get_env("CLOUDFLARE_ZONE_SUBDOMAIN")

  internal_ip = "192.168.1.51"
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

  internal_records = {
    argocd_internal = {
      name  = "argocd.internal"
      value = local.internal_ip
    },

    atlantis_internal = {
      name  = "atlantis.internal"
      value = local.internal_ip
    },

    cyberchef_internal = {
      name  = "cyberchef.internal"
      value = local.internal_ip
    },

    grafana_internal = {
      name  = "grafana.internal"
      value = local.internal_ip
    },

    home_assistant_internal = {
      name  = "home-assistant.internal"
      value = local.internal_ip
    },

    loki_internal = {
      name  = "loki.internal"
      value = local.internal_ip
    },

    longhorn_internal = {
      name  = "longhorn.internal"
      value = local.internal_ip
    },

    prometheus_internal = {
      name  = "prometheus.internal"
      value = local.internal_ip
    },

    unifi_internal = {
      name  = "unifi.internal"
      value = "192.168.1.1"
    },
  }
}
