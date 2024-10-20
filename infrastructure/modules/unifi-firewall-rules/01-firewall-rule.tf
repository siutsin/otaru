resource "unifi_firewall_rule" "this" {
  for_each = var.firewall_rules

  action                 = each.value.action
  dst_address            = each.value.dst_address
  dst_firewall_group_ids = each.value.dst_firewall_group_ids
  dst_network_type       = each.value.dst_network_type
  dst_port               = each.value.dst_port
  enabled                = each.value.enabled
  logging                = each.value.logging
  name                   = each.value.name
  protocol               = each.value.protocol
  rule_index             = each.value.rule_index
  ruleset                = each.value.ruleset
  src_firewall_group_ids = each.value.src_firewall_group_ids
}
