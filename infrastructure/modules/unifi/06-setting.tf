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

  syslog = each.value.syslog == null ? null : {
    enabled          = each.value.syslog.enabled
    ip               = each.value.syslog.ip
    log_all_contents = each.value.syslog.log_all_contents
    port             = each.value.syslog.port
    this_controller = {
      enabled        = each.value.syslog.this_controller
      encrypted_only = each.value.syslog.this_controller_encrypted_only
    }
  }

  usg = each.value.usg == null ? null : {
    broadcast_ping    = each.value.usg.broadcast_ping
    receive_redirects = each.value.usg.receive_redirects
    send_redirects    = each.value.usg.send_redirects
    syn_cookies       = each.value.usg.syn_cookies
    upnp = {
      enabled         = each.value.usg.upnp_enabled
      nat_pmp_enabled = each.value.usg.upnp_nat_pmp_enabled
      secure_mode     = each.value.usg.upnp_secure_mode
      wan_interface   = each.value.usg.upnp_wan_interface
    }
  }

  mgmt = {
    advanced_feature_enabled = each.value.mgmt.advanced_feature_enabled
    debug_tools_enabled      = each.value.mgmt.debug_tools_enabled
    direct_connect_enabled   = each.value.mgmt.direct_connect_enabled
    unifi_idp_enabled        = each.value.mgmt.unifi_idp_enabled
    wifiman_enabled          = each.value.mgmt.wifiman_enabled
    auto_upgrade = {
      enabled = each.value.mgmt.auto_upgrade
      hour    = each.value.mgmt.auto_upgrade_hour
    }
    ssh = {
      auth_password_enabled = each.value.mgmt.ssh_auth_password_enabled
      enabled               = each.value.mgmt.ssh_enabled
      keys = [{
        key  = each.value.ssh_public_key
        name = each.value.ssh_key_name
        type = each.value.ssh_key_type
      }]
    }
  }
}
