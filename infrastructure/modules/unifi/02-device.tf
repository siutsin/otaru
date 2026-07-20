resource "unifi_device" "device" {
  for_each = var.device

  mac         = each.value.mac
  radio_table = each.value.radio_table

  dynamic "port_override" {
    for_each = each.value.port_overrides

    content {
      index                 = port_override.value.index
      native_networkconf_id = unifi_network.vlan[port_override.value.native_network_id_key].id
    }
  }

  lifecycle {
    # Imported devices do not report the provider's client-side adoption and
    # destroy flags.
    ignore_changes = [
      allow_adoption,
      forget_on_destroy,
    ]
  }
}
