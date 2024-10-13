include {
  path = find_in_parent_folders()
}

terraform {
  source = "${get_parent_terragrunt_dir()}//modules/unifi"
}

locals {
  wlan01_password = get_env("UNIFI_LHR_WLAN01_PASSWORD")
  wlan01_ssid     = get_env("UNIFI_LHR_WLAN01_SSID")
  wlan02_password = get_env("UNIFI_LHR_WLAN02_PASSWORD")
  wlan02_ssid     = get_env("UNIFI_LHR_WLAN02_SSID")
  wlan03_password = get_env("UNIFI_LHR_WLAN03_PASSWORD")
  wlan03_ssid     = get_env("UNIFI_LHR_WLAN03_SSID")
  wlan04_password = get_env("UNIFI_LHR_WLAN04_PASSWORD")
  wlan04_ssid     = get_env("UNIFI_LHR_WLAN04_SSID")
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
      domain_name = "service.localdomain"
      name        = "Service"
      subnet      = "192.168.1.0/24"
    }
    # UniFi Teleport (vlan_id: 1) range 192.168.2.0 - 192.168.2.255
    vlan01 = {
      dhcp_start  = "192.168.3.6"
      dhcp_stop   = "192.168.3.254"
      domain_name = "guest.localdomain"
      name        = "Guest"
      purpose     = "guest"
      subnet      = "192.168.3.0/24"
      vlan_id     = 3
    }
    vlan02 = {
      dhcp_start  = "192.168.4.6"
      dhcp_stop   = "192.168.4.254"
      domain_name = "client.localdomain"
      name        = "Client"
      subnet      = "192.168.4.0/24"
      vlan_id     = 4
    }
    vlan03 = {
      dhcp_start  = "192.168.5.6"
      dhcp_stop   = "192.168.5.254"
      domain_name = "public.iot.localdomain"
      name        = "IoT Public"
      subnet      = "192.168.5.0/24"
      vlan_id     = 5
      # Manually enabled Isolated Network
    }
    vlan04 = {
      dhcp_start  = "192.168.6.6"
      dhcp_stop   = "192.168.6.254"
      domain_name = "private.iot.localdomain"
      name        = "IoT Private"
      subnet      = "192.168.6.0/24"
      vlan_id     = 6
      # Manually enabled Isolated Network
    }
  }
  wlan = {
    wlan01 = {
      name           = local.wlan01_ssid
      network_id_key = "vlan01"
      passphrase     = local.wlan01_password
    }
    wlan02 = {
      name           = local.wlan02_ssid
      network_id_key = "vlan02"
      passphrase     = local.wlan02_password
    }
    wlan03 = {
      name           = local.wlan03_ssid
      network_id_key = "vlan03"
      passphrase     = local.wlan03_password
    }
    wlan04 = {
      name           = local.wlan04_ssid
      network_id_key = "vlan04"
      passphrase     = local.wlan04_password
    }
  }
}
