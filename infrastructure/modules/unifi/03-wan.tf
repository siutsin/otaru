resource "unifi_wan" "wan" {
  for_each = var.wan

  name         = each.value.name
  networkgroup = each.value.wan_networkgroup
  type         = each.value.wan_type
  type_v6      = each.value.wan_type_v6

  dhcpv6 = {
    pd_size = each.value.wan_dhcp_v6_pd_size
  }

  dns = {
    preference = length(each.value.wan_dns) == 0 ? "auto" : "manual"
    primary    = try(each.value.wan_dns[0], null)
    secondary  = try(each.value.wan_dns[1], null)
  }
}
