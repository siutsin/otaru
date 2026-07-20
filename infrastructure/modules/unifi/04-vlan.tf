resource "unifi_network" "vlan" {
  for_each = var.vlan

  auto_scale          = each.value.auto_scale
  domain_name         = each.value.domain_name == "" ? null : each.value.domain_name
  ipv6_interface_type = each.value.ipv6_interface_type
  ipv6_pd_start       = each.value.ipv6_pd_start == "" ? null : each.value.ipv6_pd_start
  ipv6_pd_stop        = each.value.ipv6_pd_stop == "" ? null : each.value.ipv6_pd_stop
  ipv6_ra             = each.value.ipv6_ra_enable
  ipv6_ra_priority    = each.value.ipv6_ra_priority == "" ? null : each.value.ipv6_ra_priority
  lte_lan             = each.value.lte_lan
  multicast_dns       = each.value.multicast_dns
  name                = each.value.name
  purpose             = each.value.purpose
  setting_preference  = each.value.setting_preference
  subnet              = each.value.subnet
  vlan                = each.value.vlan_id == 0 ? null : each.value.vlan_id

  dhcp_server = {
    dns_enabled = length(each.value.dhcp_dns) > 0
    dns_servers = length(each.value.dhcp_dns) > 0 ? each.value.dhcp_dns : null
    enabled     = each.value.dhcp_enabled
    start       = each.value.dhcp_start
    stop        = each.value.dhcp_stop
  }
}
