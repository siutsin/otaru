include {
  path = find_in_parent_folders()
}

terraform {
  source = "${get_parent_terragrunt_dir()}//modules/unifi-firewall-rules"
}

dependencies {
  paths = ["../unifi"]
}

locals {
  mock_outputs = {
    firewall_group = {
      id = "id"
    }
  }

  gateway_ip = "192.168.1.51"
  vlans      = ["vlan01", "vlan03", "vlan04", "vlan05", "vlan06", "vlan07"]
}

dependency "unifi" {
  config_path = "../unifi"

  mock_outputs = {
    firewall_group_vlans   = { for vlan in local.vlans : vlan => local.mock_outputs.firewall_group }
    firewall_group_rfc1918 = local.mock_outputs.firewall_group
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

# Rule Types
#
# The rules are grouped based on the type of network that they apply to. The following network types are used:
#
# Internet: Contains IPv4 firewall rules that apply to the Internet network.
# LAN: Contains IPv4 firewall rules that apply to the LAN (Corporate) network.
# Guest: Contains IPv4 firewall rules that apply to the Guest network.
# Internet v6: Contains IPv6 firewall rules that apply to the Internet network.
# LAN v6: Contains IPv6 firewall rules that apply to the LAN (Corporate) network.
# Guest v6: Contains IPv6 firewall rules that apply to the Guest network.
#
# Rule Directionality
#
# Besides the network type, the firewall rules also apply to a direction. The following directions are used:
#
# Local: Applies to traffic that is destined for the UDM/USG itself.
# In: Applies to traffic that is entering the interface (ingress), destined for other networks.
# Out: Applies to traffic that is exiting the interface (egress), destined for this network.
#
# For example, firewall rules configured under LAN In will apply to traffic from the LAN (Corporate) network, destined for other networks. Firewall rules configured under LAN
# Local will apply to traffic from the LAN (Corporate) network, destined for the UDM/USG itself.

inputs = {
  firewall_rules = {
    # Common
    allow_all_vlans_to_otaru_gateway = {
      action     = "accept"
      name       = "Allow Traffic from All VLANs to Otaru Gateway"
      rule_index = 20000
      ruleset    = "LAN_IN"

      src_firewall_group_ids = [dependency.unifi.outputs.firewall_group_rfc1918.id]
      dst_address            = local.gateway_ip
    }
    # IoT Public
    allow_iot_public_to_self = {
      action     = "accept"
      name       = "Allow Traffic from IoT Public to itself"
      rule_index = 20500
      ruleset    = "LAN_IN"

      src_firewall_group_ids = [dependency.unifi.outputs.firewall_group_vlans["vlan05"].id]
      dst_firewall_group_ids = [dependency.unifi.outputs.firewall_group_vlans["vlan05"].id]
    }
    block_iot_public_to_all_vlans = {
      action     = "drop"
      name       = "Block Traffic from IoT Public to All VLANs"
      rule_index = 20510
      ruleset    = "LAN_IN"

      src_firewall_group_ids = [dependency.unifi.outputs.firewall_group_vlans["vlan05"].id]
      dst_firewall_group_ids = [dependency.unifi.outputs.firewall_group_rfc1918.id]
    }
    # IoT Private
    allow_iot_private_to_self = {
      action     = "accept"
      name       = "Allow Traffic from IoT Private to itself"
      rule_index = 20600
      ruleset    = "LAN_IN"

      src_firewall_group_ids = [dependency.unifi.outputs.firewall_group_vlans["vlan06"].id]
      dst_firewall_group_ids = [dependency.unifi.outputs.firewall_group_vlans["vlan06"].id]
    }
    block_iot_private_to_all_vlans = {
      action     = "drop"
      name       = "Block Traffic from IoT Private to All VLANs"
      rule_index = 20610
      ruleset    = "LAN_IN"

      src_firewall_group_ids = [dependency.unifi.outputs.firewall_group_vlans["vlan06"].id]
      dst_firewall_group_ids = [dependency.unifi.outputs.firewall_group_rfc1918.id]
    }
    block_iot_private_to_internet = {
      action     = "drop"
      name       = "Block Traffic from IoT Private to Internet"
      rule_index = 20620
      ruleset    = "WAN_OUT"

      src_firewall_group_ids = [dependency.unifi.outputs.firewall_group_vlans["vlan06"].id]
    }
  }
}
