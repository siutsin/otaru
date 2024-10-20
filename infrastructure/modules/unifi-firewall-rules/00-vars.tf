# https://registry.terraform.io/providers/paultyng/unifi/latest/docs/resources/firewall_rule
variable "firewall_rules" {
  type = map(object({
    action                 = string
    dst_address            = optional(string)
    dst_firewall_group_ids = optional(list(string))
    dst_network_type       = optional(string, "NETv4")
    dst_port               = optional(string)
    enabled                = optional(bool, true)
    logging                = optional(bool, false)
    name                   = string
    protocol               = optional(string, "all")
    rule_index             = number
    ruleset                = string
    src_firewall_group_ids = optional(list(string))
  }))
  default = {}
}
