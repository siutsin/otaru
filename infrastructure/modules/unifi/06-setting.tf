resource "unifi_setting_mgmt" "this" {
  for_each = var.setting

  auto_upgrade = true
  site         = unifi_site.site[each.value.site_key].name
  ssh_enabled  = true

  ssh_key {
    name = each.value.ssh_key_name
    type = each.value.ssh_key_type
    key  = each.value.ssh_public_key
  }
}
