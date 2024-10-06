include {
  path = find_in_parent_folders()
}

terraform {
  source = "${get_parent_terragrunt_dir()}//modules/unifi"
}

inputs = {
  site = {
    site00 = {
      description = "Default"
    }
  }
  device = {
    gateway00 = {
      name = "Cloud Gateway Ultra"
    }
    switch00 = {
      name = "USW Lite 8 PoE"
    }
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
