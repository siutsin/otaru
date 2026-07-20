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

output "clients" {
  value = {
    for k, v in unifi_client.this : k => {
      fixed_ip = v.fixed_ip
    }
  }
}

output "networks" {
  value = {
    for k, v in unifi_network.vlan : k => {
      id = v.id
    }
  }
}
