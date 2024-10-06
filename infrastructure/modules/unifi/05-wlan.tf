data "unifi_ap_group" "default" {
}

data "unifi_user_group" "default" {
}

resource "unifi_wlan" "wlan" {
  for_each = var.wlan

  ap_group_ids    = [data.unifi_ap_group.default.id]
  name            = each.value.name
  network_id      = unifi_network.vlan[each.value.network_id_key].id
  passphrase      = each.value.passphrase
  pmf_mode        = each.value.pmf_mode
  security        = each.value.security
  user_group_id   = data.unifi_user_group.default.id
  wlan_band       = each.value.wlan_band
  wpa3_support    = each.value.wpa3_support
  wpa3_transition = each.value.wpa3_transition
}
