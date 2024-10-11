variable "site" {
  type = map(object({
    description = string
  }))
}

variable "device" {
  type = map(object({
    name = string
  }))
}

variable "wan" {
  type = map(object({
    name             = string
    purpose          = optional(string, "wan")
    wan_dns          = list(string)
    wan_networkgroup = string
    wan_type         = string
    wan_type_v6      = string
  }))
}

variable "vlan" {
  type = map(object({
    dhcp_dns               = optional(list(string), ["192.168.1.51", "1.1.1.1", "1.0.0.1"])
    dhcp_enabled           = optional(bool, true)
    dhcp_start             = string
    dhcp_stop              = string
    dhcp_v6_start          = optional(string, "::2")
    dhcp_v6_stop           = optional(string, "::7d1")
    domain_name            = optional(string, "")
    ipv6_interface_type    = optional(string, "none")
    ipv6_pd_start          = optional(string, "::2")
    ipv6_pd_stop           = optional(string, "::7d1")
    ipv6_ra_enable         = optional(bool, true)
    ipv6_ra_priority       = optional(string, "high")
    ipv6_ra_valid_lifetime = optional(number, 0)
    multicast_dns          = optional(bool, true)
    name                   = string
    purpose                = optional(string, "corporate")
    subnet                 = string
    vlan_id                = optional(number, 0)
  }))
}

variable "wlan" {
  type = map(object({
    name            = string
    network_id_key  = string
    passphrase      = string
    pmf_mode        = optional(string, "optional")
    security        = optional(string, "wpapsk")
    wlan_band       = optional(string, "both")
    wpa3_support    = optional(bool, true)
    wpa3_transition = optional(bool, true)
  }))
}
