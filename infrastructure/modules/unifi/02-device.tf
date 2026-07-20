resource "unifi_device" "device" {
  for_each = var.device

  mac = each.value.mac

  lifecycle {
    # Imported devices do not report the provider's client-side adoption and
    # destroy flags. Port configuration is maintained in the live controller.
    ignore_changes = [
      allow_adoption,
      forget_on_destroy,
      port_override,
    ]
  }
}
