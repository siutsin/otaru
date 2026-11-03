resource "unifi_network" "vlan" {
  for_each = var.vlan

  auto_scale         = each.value.auto_scale
  domain_name        = each.value.domain_name == "" ? null : each.value.domain_name
  lte_lan            = each.value.lte_lan
  multicast_dns      = each.value.multicast_dns
  name               = each.value.name
  purpose            = each.value.purpose
  setting_preference = each.value.setting_preference
  subnet             = each.value.subnet
  vlan               = each.value.vlan_id == 0 ? null : each.value.vlan_id

  dhcp_server = {
    dns = {
      enabled = length(each.value.dhcp_dns) > 0
      servers = length(each.value.dhcp_dns) > 0 ? each.value.dhcp_dns : null
    }
    enabled = each.value.dhcp_enabled
    start   = each.value.dhcp_start
    stop    = each.value.dhcp_stop
  }

  ipv6 = {
    interface_type = each.value.ipv6_interface_type
    pd = {
      start = each.value.ipv6_pd_start == "" ? null : each.value.ipv6_pd_start
      stop  = each.value.ipv6_pd_stop == "" ? null : each.value.ipv6_pd_stop
    }
    ra = {
      enabled  = each.value.ipv6_ra_enable
      priority = each.value.ipv6_ra_priority == "" ? null : each.value.ipv6_ra_priority
    }
  }
}
