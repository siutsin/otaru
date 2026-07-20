resource "unifi_setting" "this" {
  for_each = var.setting

  site = unifi_site.site[each.value.site_key].name

  mgmt = {
    auto_upgrade = true
    ssh_enabled  = true
    ssh_keys = [{
      key  = each.value.ssh_public_key
      name = each.value.ssh_key_name
      type = each.value.ssh_key_type
    }]
  }
}
