include {
  path = find_in_parent_folders()
}

terraform {
  source = "${get_parent_terragrunt_dir()}//modules/unifi"
}

locals {
  wlan00_password = get_env("UNIFI_LHR_WLAN00_PASSWORD")
  wlan00_ssid     = get_env("UNIFI_LHR_WLAN00_SSID")
  wlan01_password = get_env("UNIFI_LHR_WLAN01_PASSWORD")
  wlan01_ssid     = get_env("UNIFI_LHR_WLAN01_SSID")
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
      dhcp_start  = "192.168.1.6"
      dhcp_stop   = "192.168.1.254"
      domain_name = "localdomain"
      name        = "Default"
      subnet      = "192.168.1.0/24"
    }
  }
  wlan = {
    wlan00 = {
      name           = local.wlan00_ssid
      network_id_key = "vlan00"
      passphrase     = local.wlan00_password
    }
    wlan01 = {
      name           = local.wlan01_ssid
      network_id_key = "vlan00"
      passphrase     = local.wlan01_password
      wlan_band      = "2g"
    }
  }
}
