variable "site" {
  type = map(object({
    description = string
  }))
}

variable "client" {
  type = map(object({
    fixed_ip = string
    mac      = string
  }))
}

variable "device" {
  type = map(object({
    mac = string
    port_overrides = optional(map(object({
      index                 = number
      native_network_id_key = string
    })), {})
    radio_table = optional(list(object({
      channel = string
      ht      = number
      radio   = string
    })))
  }))
}

variable "wan" {
  type = map(object({
    name                = string
    wan_dhcp_v6_pd_size = optional(number, 48)
    wan_dns             = list(string)
    wan_networkgroup    = string
    wan_type            = string
    wan_type_v6         = string
  }))
}

variable "vlan" {
  type = map(object({
    auto_scale          = optional(bool, false)
    dhcp_dns            = optional(list(string), ["192.168.10.51", "1.1.1.2"])
    dhcp_enabled        = optional(bool, true)
    dhcp_start          = string
    dhcp_stop           = string
    domain_name         = optional(string, "local")
    ipv6_interface_type = optional(string, "none")
    ipv6_pd_start       = optional(string, "::2")
    ipv6_pd_stop        = optional(string, "::7d1")
    ipv6_ra_enable      = optional(bool, true)
    ipv6_ra_priority    = optional(string, "high")
    lte_lan             = optional(bool, false)
    multicast_dns       = optional(bool, true)
    name                = string
    purpose             = optional(string, "corporate")
    setting_preference  = optional(string, "manual")
    subnet              = string
    vlan_id             = optional(number, 0)
  }))
}

variable "firewall_group_vlan_keys" {
  type = set(string)
}

variable "wlan" {
  type = map(object({
    bss_transition  = optional(bool, true)
    group_rekey     = optional(number, 3600)
    name            = string
    network_id_key  = string
    passphrase      = string
    pmf_mode        = optional(string, "optional")
    security        = optional(string, "wpapsk")
    wlan_band       = optional(string, "both")
    wlan_bands      = optional(set(string), ["2g", "5g"])
    wpa3_support    = optional(bool, true)
    wpa3_transition = optional(bool, true)
  }))
}

variable "setting" {
  type = map(object({
    auto_speedtest = optional(object({
      cron_expr = string
      enabled   = bool
    }))
    country = optional(object({
      code = number
    }))
    doh = optional(object({
      server_names = list(string)
      state        = string
    }))
    dpi = optional(object({
      enabled                = bool
      fingerprinting_enabled = bool
    }))
    igmp_snooping = optional(object({
      enabled     = bool
      network_ids = list(string)
    }))
    ips = optional(object({
      advanced_filtering_preference           = string
      content_filtering_blocking_page_enabled = bool
      enabled_categories                      = list(string)
      honeypot_enabled                        = bool
      ips_mode                                = string
      memory_optimized                        = bool
    }))
    lcm = optional(object({
      brightness   = number
      enabled      = bool
      idle_timeout = number
      sync         = bool
      touch_event  = bool
    }))
    mgmt = object({
      advanced_feature_enabled  = bool
      auto_upgrade              = bool
      auto_upgrade_hour         = number
      debug_tools_enabled       = bool
      direct_connect_enabled    = bool
      ssh_auth_password_enabled = bool
      ssh_enabled               = bool
      unifi_idp_enabled         = bool
      wifiman_enabled           = bool
    })
    network_optimization = optional(object({
      enabled = bool
    }))
    ntp = optional(object({
      ntp_server_1       = string
      ntp_server_2       = string
      ntp_server_3       = string
      ntp_server_4       = string
      setting_preference = string
    }))
    site_key       = string
    ssh_key_name   = optional(string, "UniFi Site Manager")
    ssh_key_type   = optional(string, "ssh-rsa")
    ssh_public_key = string
    syslog = optional(object({
      enabled                        = bool
      log_all_contents               = bool
      this_controller                = bool
      this_controller_encrypted_only = bool
    }))
    usg = optional(object({
      broadcast_ping       = bool
      receive_redirects    = bool
      send_redirects       = bool
      syn_cookies          = bool
      upnp_enabled         = bool
      upnp_nat_pmp_enabled = bool
      upnp_secure_mode     = bool
      upnp_wan_interface   = string
    }))
  }))
}
