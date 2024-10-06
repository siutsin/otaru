resource "unifi_device" "device" {
  for_each = var.device

  name = each.value.name
}
