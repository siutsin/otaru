resource "unifi_network" "wan" {
  for_each = var.wan

  name                = each.value.name
  purpose             = each.value.purpose
  wan_dhcp_v6_pd_size = each.value.wan_dhcp_v6_pd_size
  wan_dns             = each.value.wan_dns
  wan_networkgroup    = each.value.wan_networkgroup
  wan_type            = each.value.wan_type
  wan_type_v6         = each.value.wan_type_v6
}
