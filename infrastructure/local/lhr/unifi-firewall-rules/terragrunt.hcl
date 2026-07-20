include {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_parent_terragrunt_dir()}//modules/unifi-firewall-rules"
}

dependencies {
  paths = ["../unifi"]
}

locals {
  media_receiver_client_keys = [
    "kitchen_airplay",
    "living_room_homepod",
    "nvidia_shield",
  ]

  mock_outputs = {
    firewall_group = {
      id = "id"
    }
    client = {
      fixed_ip = "192.0.2.1"
    }
  }

  k3s_ingress_ip = "192.168.10.51"
  vlans          = ["vlan01", "vlan03", "vlan04", "vlan05", "vlan06", "vlan07", "vlan08", "vlan10"]
}

dependency "unifi" {
  config_path = "../unifi"

  mock_outputs = {
    clients                = { for client_key in local.media_receiver_client_keys : client_key => local.mock_outputs.client }
    firewall_group_vlans   = { for vlan in local.vlans : vlan => local.mock_outputs.firewall_group }
    firewall_group_rfc1918 = local.mock_outputs.firewall_group
    networks               = { for vlan in local.vlans : vlan => local.mock_outputs.firewall_group }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  firewall_policies = {
    allow_hotspot_k3s_web_dns = {
      action               = "ALLOW"
      create_allow_respond = true
      description          = "Allow guest devices to use DNS and web services exposed through the K3s ingress."
      name                 = "Allow Hotspot to K3s Web and DNS"
      protocol             = "tcp_udp"

      source = {
        zone = "Hotspot"
      }
      destination = {
        ips             = [local.k3s_ingress_ip]
        matching_target = "IP"
        port            = "53,443"
        zone            = "Internal"
      }
    }
    allow_internal_ingress = {
      action               = "ALLOW"
      create_allow_respond = true
      description          = "Allow devices on internal networks to reach services exposed through the K3s ingress."
      name                 = "Allow Internal to K3s Ingress"

      source = {
        zone = "Internal"
      }
      destination = {
        ips             = [local.k3s_ingress_ip]
        matching_target = "IP"
        zone            = "Internal"
      }
    }
    allow_guest_media_receivers = {
      action               = "ALLOW"
      create_allow_respond = true
      description          = "Allow guest devices to use the household AirPlay, Chromecast, and Spotify Connect receivers."
      ip_version           = "BOTH"
      name                 = "Allow Guest Media Receivers"

      source = {
        zone = "Hotspot"
      }
      destination = {
        ips = [
          for client_key in local.media_receiver_client_keys : dependency.unifi.outputs.clients[client_key].fixed_ip
        ]
        # This controller firmware rejects CLIENT targets, so stable client reservations are matched by IP.
        matching_target = "IP"
        zone            = "Internal"
      }
    }
    allow_vpn_ingress = {
      action               = "ALLOW"
      create_allow_respond = true
      description          = "Allow remote VPN devices to reach services exposed through the K3s ingress."
      name                 = "Allow VPN to K3s Ingress"

      source = {
        zone = "Vpn"
      }
      destination = {
        ips             = [local.k3s_ingress_ip]
        matching_target = "IP"
        zone            = "Internal"
      }
    }
    block_restricted_internal = {
      action = "BLOCK"
      # Keep the K3s ingress exception above this broad Internal-to-Internal deny.
      allow_policy_keys_before = ["allow_internal_ingress"]
      connection_state_type    = "CUSTOM"
      connection_states        = ["NEW", "INVALID"]
      description              = "Prevent devices on the Default and IoT networks from initiating connections to other internal networks."
      ip_version               = "BOTH"
      logging                  = true
      name                     = "Block Restricted Networks to Internal"

      source = {
        matching_target = "NETWORK"
        network_ids = [
          dependency.unifi.outputs.networks["vlan01"].id,
          dependency.unifi.outputs.networks["vlan05"].id,
          dependency.unifi.outputs.networks["vlan06"].id,
        ]
        zone = "Internal"
      }
      destination = {
        zone = "Internal"
      }
    }
    block_private_iot_internet = {
      action      = "BLOCK"
      description = "Keep private IoT devices off the Internet."
      ip_version  = "BOTH"
      name        = "Block Private IoT Internet"

      source = {
        matching_target = "NETWORK"
        network_ids     = [dependency.unifi.outputs.networks["vlan06"].id]
        zone            = "Internal"
      }
      destination = {
        zone = "External"
      }
    }
  }
}
