resource "unifi_setting" "this" {
  for_each = var.setting

  auto_speedtest = each.value.auto_speedtest
  country        = each.value.country
  doh            = each.value.doh
  dpi            = each.value.dpi
  igmp_snooping  = each.value.igmp_snooping
  ips = each.value.ips == null ? null : merge(
    { for key, value in each.value.ips : key => value if key != "enabled_network_keys" },
    {
      enabled_networks = [
        for network_key in each.value.ips.enabled_network_keys : unifi_network.vlan[network_key].id
      ]
    },
  )
  lcm                  = each.value.lcm
  network_optimization = each.value.network_optimization
  ntp                  = each.value.ntp
  site                 = unifi_site.site[each.value.site_key].name
  syslog               = each.value.syslog
  usg                  = each.value.usg

  mgmt = merge(each.value.mgmt, {
    ssh_keys = [{
      key  = each.value.ssh_public_key
      name = each.value.ssh_key_name
      type = each.value.ssh_key_type
    }]
  })
}
