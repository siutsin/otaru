resource "unifi_device" "gateway" {
  for_each = var.device_gateway

  name = each.value.name
}

resource "unifi_device" "switch" {
  for_each = var.device_switch

  name = each.value.name
}

resource "unifi_device" "wifi" {
  for_each = var.device_wifi

  name = each.value.name
}

