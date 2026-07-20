resource "unifi_client" "this" {
  for_each = var.client

  fixed_ip = each.value.fixed_ip
  # MAC addresses come from the private tfconfig and must stay redacted in plans.
  mac = sensitive(each.value.mac)

  lifecycle {
    # Removing Terraform ownership must not forget a known client in UniFi.
    prevent_destroy = true
  }
}
