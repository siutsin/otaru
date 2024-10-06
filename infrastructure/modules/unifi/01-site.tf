resource "unifi_site" "site" {
  for_each = var.site

  description = each.value.description
}
