resource "unifi_network" "vlan" {
  for_each = var.vlan

  dhcp_enabled           = each.value.dhcp_enabled
  dhcp_start             = each.value.dhcp_start
  dhcp_stop              = each.value.dhcp_stop
  dhcp_v6_start          = each.value.dhcp_v6_start
  dhcp_v6_stop           = each.value.dhcp_v6_stop
  domain_name            = each.value.domain_name
  ipv6_interface_type    = each.value.ipv6_interface_type
  ipv6_pd_start          = each.value.ipv6_pd_start
  ipv6_pd_stop           = each.value.ipv6_pd_stop
  ipv6_ra_enable         = each.value.ipv6_ra_enable
  ipv6_ra_priority       = each.value.ipv6_ra_priority
  ipv6_ra_valid_lifetime = each.value.ipv6_ra_valid_lifetime
  multicast_dns          = each.value.multicast_dns
  name                   = each.value.name
  purpose                = each.value.purpose
  subnet                 = each.value.subnet
  vlan_id                = each.value.vlan_id
}
