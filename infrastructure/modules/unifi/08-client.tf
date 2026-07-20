resource "unifi_client" "this" {
  for_each = var.client

  fixed_ip = each.value.fixed_ip
  mac      = each.value.mac

  lifecycle {
    # Removing Terraform ownership must not forget a known client in UniFi.
    prevent_destroy = true
  }
}
