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
    vlan01 = {
      dhcp_start  = "192.168.1.6"
      dhcp_stop   = "192.168.1.254"
      domain_name = "service.localdomain"
      name        = "Service"
      subnet      = "192.168.1.0/24"
    }
    # UniFi Teleport (vlan_id: 1) range 192.168.2.0 - 192.168.2.255.
    vlan03 = {
      dhcp_start  = "192.168.3.6"
      dhcp_stop   = "192.168.3.254"
      domain_name = "guest.localdomain"
      name        = "Guest"
      purpose     = "guest"
      subnet      = "192.168.3.0/24"
      vlan_id     = 3
    }
    vlan04 = {
      dhcp_start  = "192.168.4.6"
      dhcp_stop   = "192.168.4.254"
      domain_name = "client.localdomain"
      name        = "Client"
      subnet      = "192.168.4.0/24"
      vlan_id     = 4
    }
    vlan05 = {
      dhcp_start  = "192.168.5.6"
      dhcp_stop   = "192.168.5.254"
      domain_name = "public.iot.localdomain"
      name        = "IoT Public"
      subnet      = "192.168.5.0/24"
      vlan_id     = 5
    }
    vlan06 = {
      dhcp_start  = "192.168.6.6"
      dhcp_stop   = "192.168.6.254"
      domain_name = "private.iot.localdomain"
      name        = "IoT Private"
      subnet      = "192.168.6.0/24"
      vlan_id     = 6
    }
    vlan07 = {
      dhcp_start  = "192.168.7.6"
      dhcp_stop   = "192.168.7.254"
      domain_name = "work.localdomain"
      name        = "Work"
      subnet      = "192.168.7.0/24"
      vlan_id     = 7
    }
  }
  wlan = {
    wlan01 = {
      name           = local.wlan01_ssid
      network_id_key = "vlan03"
      passphrase     = local.wlan01_password
    }
    wlan02 = {
      name           = local.wlan02_ssid
      network_id_key = "vlan04"
      passphrase     = local.wlan02_password
    }
    wlan03 = {
      name           = local.wlan03_ssid
      network_id_key = "vlan05"
      passphrase     = local.wlan03_password
    }
    wlan04 = {
      name           = local.wlan04_ssid
      network_id_key = "vlan06"
      passphrase     = local.wlan04_password
    }
  }
  setting = {
    setting00 = {
      site_key       = "site00"
      ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC7Hl8gjq6bsgtlkTBxeuEJs0y22YlYll//0Eg+0E0pSkE4lTk8rRva4oVGO4JM5jdNfyHdyvblrXTkMVAoaAj5WJZ3Ia74kN/x3S3pKDASPPW+KCI+Lgq+n474Oi5M0C0AxQgE5fNlEoRcosjTroxPVOBRi/kDSirqc4x60n9YbCaL+/XWo6EhqHieq+AKBzE/mU1gmbej0lrvG9Iyiu1F+VtJel5OTsXU8/czzHHApdegiXUNbw7KVVuCYdWK6ihBib0hEhbDaZNCYQeYuMF5F3MYU8q/WCXe56ditftUX9GPs7m71/15vBsdNFLqhpFTtMdnn/z5FFLYnT9Qp4TobXnZc8F7/gZ1ghdI01pzYpg0TvInbe/KDDRlfFf5GqWhqFPoReK2yAI3nBHZkovnDct292pqsgMe27SAY16ULyzEnt+mJCofTafuZzWZlmXZum3/symt4G+l77Bscq2tJ0OfVY0YhHh7cCXTpDrb4yJrRB8BrwFrqAlC3Xbn+0NcX42DQs6B8TMlWxm19yriGRagbZJ4lPOucBUZSxKXtrFFT8aSvhiPgFJ+b92bl7sY7Po2Gnv3FkDpb9RvyP76Odv5Sm+O9vDIhtHRUEoxNxdnwsfWoqjl2Y9sCOZ6Q+eoQ11QWvEPRkvtxKDKrCd1pNkC7OlvVnsQLEHyRRO3Dw=="
    }
  }
}
