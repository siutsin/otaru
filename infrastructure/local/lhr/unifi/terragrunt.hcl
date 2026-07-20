include {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_parent_terragrunt_dir()}//modules/unifi"
}

locals {
  tfconfig        = jsondecode(file(get_env("OTARU_TF_CONFIG_FILE")))
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
  client = {
    jetkvm = {
      fixed_ip = "192.168.10.41"
      mac      = local.tfconfig.unifi.clients.jetkvm.mac
    }
  }
  site = {
    site00 = {
      description = "Default"
    }
  }
  device = {
    gateway00 = { # Cloud Gateway Ultra
      mac = local.tfconfig.unifi.devices.gateway00.mac
    }
    switch00 = { # USW Lite 8 PoE
      mac = local.tfconfig.unifi.devices.switch00.mac
    }
    switch01 = { # Switch Ultra
      mac = local.tfconfig.unifi.devices.switch01.mac
    }
    wifi00 = { # U7 Pro Back
      mac = local.tfconfig.unifi.devices.wifi00.mac
    }
    wifi01 = { # U7 Pro Front
      mac = local.tfconfig.unifi.devices.wifi01.mac
    }
  }
  # Only VLAN address groups that already exist in the controller are managed.
  firewall_group_vlan_keys = toset([
    "vlan01",
    "vlan03",
    "vlan04",
    "vlan05",
    "vlan06",
    "vlan07",
  ])
  wan = {
    wan00 = {
      name             = "Internet 1"
      wan_dns          = []
      wan_networkgroup = "WAN"
      wan_type         = "dhcp"
      wan_type_v6      = "dhcpv6"
    }
  }
  vlan = {
    vlan01 = {
      dhcp_start = "192.168.1.6"
      dhcp_stop  = "192.168.1.254"
      name       = "Default"
      subnet     = "192.168.1.1/24"
    }
    # UniFi Teleport (vlan_id: 1) range 192.168.2.0 - 192.168.2.255.
    vlan03 = {
      dhcp_start = "192.168.3.6"
      dhcp_stop  = "192.168.3.254"
      name       = "Guest"
      purpose    = "guest"
      subnet     = "192.168.3.1/24"
      vlan_id    = 3
    }
    vlan04 = {
      dhcp_start = "192.168.4.100"
      dhcp_stop  = "192.168.4.254"
      name       = "Client"
      subnet     = "192.168.4.1/24"
      vlan_id    = 4
    }
    # TODO: fix chime pro issue
    # https://community.ui.com/questions/Ring-Chime-Pro-fell-off-the-network-and-wont-reconnect/b6ca1989-4495-44af-8c1d-b8ff71da1739
    # https://community.ui.com/questions/U6-pro-Ring-Chime-pro-issue/e40c5c97-121b-4579-ac06-df0fcbd89ea6
    vlan05 = {
      dhcp_start = "192.168.5.100"
      dhcp_stop  = "192.168.5.254"
      name       = "IoT Public"
      subnet     = "192.168.5.1/24"
      vlan_id    = 5
    }
    vlan06 = {
      dhcp_start = "192.168.6.6"
      dhcp_stop  = "192.168.6.40"
      name       = "IoT Private"
      subnet     = "192.168.6.1/24"
      vlan_id    = 6
    }
    vlan07 = {
      dhcp_dns   = ["1.1.1.2", "1.0.0.2"]
      dhcp_start = "192.168.7.6"
      dhcp_stop  = "192.168.7.254"
      name       = "Work"
      subnet     = "192.168.7.1/24"
      vlan_id    = 7
    }
    vlan08 = {
      auto_scale  = true
      dhcp_dns    = ["1.1.1.2", "1.0.0.2"]
      dhcp_start  = "192.168.8.6"
      dhcp_stop   = "192.168.8.254"
      domain_name = ""
      lte_lan     = true
      name        = "Unrestricted"
      subnet      = "192.168.8.1/24"
      vlan_id     = 8
    }
    vlan10 = {
      auto_scale         = true
      dhcp_dns           = []
      dhcp_start         = "192.168.10.6"
      dhcp_stop          = "192.168.10.254"
      domain_name        = ""
      ipv6_pd_start      = ""
      ipv6_pd_stop       = ""
      ipv6_ra_enable     = false
      ipv6_ra_priority   = ""
      lte_lan            = true
      name               = "Server"
      setting_preference = "auto"
      subnet             = "192.168.10.1/24"
      vlan_id            = 10
    }
  }
  wlan = {
    wlan01 = {
      name           = local.wlan01_ssid
      network_id_key = "vlan03"
      passphrase     = local.wlan01_password
      wlan_bands     = ["2g", "5g"]
    }
    wlan02 = {
      group_rekey    = 0
      name           = local.wlan02_ssid
      network_id_key = "vlan04"
      passphrase     = local.wlan02_password
      wlan_bands     = ["2g", "5g", "6g"]
    }
    wlan03 = {
      name            = local.wlan03_ssid
      network_id_key  = "vlan01" # some IoT devices do not support vlan tag. All IoT devices will assign to the default vlan from now on.
      passphrase      = local.wlan03_password
      pmf_mode        = "disabled"
      wlan_band       = "2g"
      wlan_bands      = ["2g"]
      wpa3_support    = false
      wpa3_transition = false
    }
    wlan04 = {
      name           = local.wlan04_ssid
      network_id_key = "vlan01" # some IoT devices do not support vlan tag. All IoT devices will assign to the default vlan from now on.
      passphrase     = local.wlan04_password
      wlan_bands     = ["2g", "5g", "6g"]
    }
  }
  setting = {
    setting00 = {
      site_key       = "site00"
      ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC7Hl8gjq6bsgtlkTBxeuEJs0y22YlYll//0Eg+0E0pSkE4lTk8rRva4oVGO4JM5jdNfyHdyvblrXTkMVAoaAj5WJZ3Ia74kN/x3S3pKDASPPW+KCI+Lgq+n474Oi5M0C0AxQgE5fNlEoRcosjTroxPVOBRi/kDSirqc4x60n9YbCaL+/XWo6EhqHieq+AKBzE/mU1gmbej0lrvG9Iyiu1F+VtJel5OTsXU8/czzHHApdegiXUNbw7KVVuCYdWK6ihBib0hEhbDaZNCYQeYuMF5F3MYU8q/WCXe56ditftUX9GPs7m71/15vBsdNFLqhpFTtMdnn/z5FFLYnT9Qp4TobXnZc8F7/gZ1ghdI01pzYpg0TvInbe/KDDRlfFf5GqWhqFPoReK2yAI3nBHZkovnDct292pqsgMe27SAY16ULyzEnt+mJCofTafuZzWZlmXZum3/symt4G+l77Bscq2tJ0OfVY0YhHh7cCXTpDrb4yJrRB8BrwFrqAlC3Xbn+0NcX42DQs6B8TMlWxm19yriGRagbZJ4lPOucBUZSxKXtrFFT8aSvhiPgFJ+b92bl7sY7Po2Gnv3FkDpb9RvyP76Odv5Sm+O9vDIhtHRUEoxNxdnwsfWoqjl2Y9sCOZ6Q+eoQ11QWvEPRkvtxKDKrCd1pNkC7OlvVnsQLEHyRRO3Dw=="
    }
  }
}
