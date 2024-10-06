variable "device_gateway" {
  type = map(object({
    name = string
  }))
}

variable "device_switch" {
  type = map(object({
    name = string
  }))
}

variable "device_wifi" {
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
    name                   = string
    purpose                = optional(string, "corporate")
    dhcp_enabled           = optional(bool, true)
    dhcp_start             = string
    dhcp_stop              = string
    dhcp_v6_start          = optional(string, "::2")
    dhcp_v6_stop           = optional(string, "::7d1")
    domain_name            = string
    ipv6_interface_type    = optional(string, "none")
    ipv6_pd_start          = optional(string, "::2")
    ipv6_pd_stop           = optional(string, "::7d1")
    ipv6_ra_enable         = optional(bool, true)
    ipv6_ra_priority       = optional(string, "high")
    ipv6_ra_valid_lifetime = optional(number, 0)
    multicast_dns          = optional(bool, true)
    subnet                 = string
  }))
}
