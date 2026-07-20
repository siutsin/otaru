resource "unifi_firewall_group" "rfc1918" {
  name = "RFC1918 IP Addresses"
  type = "address-group"

  members = [
    "10.0.0.0/8",
    "172.16.0.0/12",
    "192.168.0.0/16",
  ]
}

resource "unifi_firewall_group" "this" {
  for_each = {
    for key in var.firewall_group_vlan_keys : key => var.vlan[key]
  }

  members = [cidrsubnet(each.value.subnet, 0, 0)]
  name    = each.key
  type    = "address-group"
}
