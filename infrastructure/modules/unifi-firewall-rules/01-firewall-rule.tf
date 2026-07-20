locals {
  firewall_zone_names = toset(flatten([
    for policy in values(var.firewall_policies) : [
      policy.source.zone,
      policy.destination.zone,
    ]
  ]))
}

data "unifi_firewall_zone" "this" {
  for_each = local.firewall_zone_names

  name = each.value
}

resource "unifi_firewall_policy" "allow" {
  for_each = {
    for key, policy in var.firewall_policies : key => policy
    if policy.action == "ALLOW"
  }

  action                = each.value.action
  connection_state_type = each.value.connection_state_type
  connection_states     = each.value.connection_states
  create_allow_respond  = each.value.create_allow_respond
  description           = each.value.description
  enabled               = each.value.enabled
  ip_version            = each.value.ip_version
  logging               = each.value.logging
  name                  = each.value.name
  protocol              = each.value.protocol

  source = {
    ips                = each.value.source.ips
    matching_target    = each.value.source.matching_target
    network_ids        = each.value.source.network_ids
    port               = each.value.source.port
    port_matching_type = each.value.source.port == null ? null : "SPECIFIC"
    zone_id            = data.unifi_firewall_zone.this[each.value.source.zone].id
  }

  destination = {
    ips                = each.value.destination.ips
    matching_target    = each.value.destination.matching_target
    network_ids        = each.value.destination.network_ids
    port               = each.value.destination.port
    port_matching_type = each.value.destination.port == null ? null : "SPECIFIC"
    zone_id            = data.unifi_firewall_zone.this[each.value.destination.zone].id
  }

}

resource "unifi_firewall_policy" "deny" {
  for_each = {
    for key, policy in var.firewall_policies : key => policy
    if policy.action != "ALLOW"
  }

  action                = each.value.action
  connection_state_type = each.value.connection_state_type
  connection_states     = each.value.connection_states
  create_allow_respond  = each.value.create_allow_respond
  description           = each.value.description
  enabled               = each.value.enabled
  ip_version            = each.value.ip_version
  logging               = each.value.logging
  name                  = each.value.name
  protocol              = each.value.protocol

  source = {
    ips                = each.value.source.ips
    matching_target    = each.value.source.matching_target
    network_ids        = each.value.source.network_ids
    port               = each.value.source.port
    port_matching_type = each.value.source.port == null ? null : "SPECIFIC"
    zone_id            = data.unifi_firewall_zone.this[each.value.source.zone].id
  }

  destination = {
    ips                = each.value.destination.ips
    matching_target    = each.value.destination.matching_target
    network_ids        = each.value.destination.network_ids
    port               = each.value.destination.port
    port_matching_type = each.value.destination.port == null ? null : "SPECIFIC"
    zone_id            = data.unifi_firewall_zone.this[each.value.destination.zone].id
  }

  # UniFi appends policies within each zone pair, so exceptions must exist first.
  depends_on = [unifi_firewall_policy.allow]

  lifecycle {
    postcondition {
      # The provider cannot reorder policies, but its computed indices let every plan detect an unsafe live order.
      condition = alltrue([
        for allow_policy_key in each.value.allow_policy_keys_before :
        unifi_firewall_policy.allow[allow_policy_key].index < self.index
      ])
      error_message = "Unsafe live firewall order: ${join(", ", tolist(each.value.allow_policy_keys_before))} must precede ${each.key}. Reorder in UniFi and plan again."
    }
  }
}
