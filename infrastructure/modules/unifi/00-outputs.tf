output "firewall_group_vlans" {
  value = {
    for k, v in unifi_firewall_group.this : k => {
      id = v.id
    }
  }
}

output "firewall_group_rfc1918" {
  value = {
    id = unifi_firewall_group.rfc1918.id
  }
}
