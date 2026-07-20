data "unifi_ap_group" "default" {
  name = "All APs"
}

data "unifi_client_qos_rate" "default" {
  name = "Default"
}

resource "unifi_wlan" "wlan" {
  for_each = var.wlan

  ap_group_ids    = [data.unifi_ap_group.default.id]
  bss_transition  = each.value.bss_transition
  group_rekey     = each.value.group_rekey
  name            = each.value.name
  network_id      = unifi_network.vlan[each.value.network_id_key].id
  passphrase      = each.value.passphrase
  pmf_mode        = each.value.pmf_mode
  security        = each.value.security
  user_group_id   = data.unifi_client_qos_rate.default.id
  wlan_band       = each.value.wlan_band
  wlan_bands      = each.value.wlan_bands
  wpa3_support    = each.value.wpa3_support
  wpa3_transition = each.value.wpa3_transition
}
