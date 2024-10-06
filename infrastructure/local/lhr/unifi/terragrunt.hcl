include {
  path = find_in_parent_folders()
}

terraform {
  source = "${get_parent_terragrunt_dir()}//modules/unifi"
}

inputs = {
  device_gateway = {
    gateway00 = {
      name = "Cloud Gateway Ultra"
    }
  }
  device_switch = {
    switch00 = {
      name = "USW Lite 8 PoE"
    }
  }
  device_wifi = {
    wifi00 = {
      name = "U7 Pro"
    }
  }
  wan = {
    wan00 = {
      name             = "Primary (WAN1)"
      wan_dns          = ["1.1.1.2", "1.0.0.2"]
      wan_networkgroup = "WAN"
      wan_type         = "dhcp"
      wan_type_v6      = "disabled"
    }
  }
  vlan = {
    vlan00 = {
      name        = "Default"
      dhcp_start  = "192.168.1.6"
      dhcp_stop   = "192.168.1.254"
      domain_name = "localdomain"
      subnet      = "192.168.1.0/24"
    }
  }
}
