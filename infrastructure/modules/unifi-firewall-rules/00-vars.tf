variable "firewall_policies" {
  type = map(object({
    action = string
    # Explicit partial order: these ALLOW policies must have lower live indices than this BLOCK or REJECT policy.
    allow_policy_keys_before = optional(set(string), [])
    connection_state_type    = optional(string)
    connection_states        = optional(list(string))
    create_allow_respond     = optional(bool)
    description              = optional(string)
    enabled                  = optional(bool, true)
    ip_version               = optional(string, "IPV4")
    logging                  = optional(bool, false)
    name                     = string
    protocol                 = optional(string, "all")
    source = object({
      ips             = optional(list(string))
      matching_target = optional(string, "ANY")
      network_ids     = optional(list(string))
      port            = optional(string)
      zone            = string
    })
    destination = object({
      ips             = optional(list(string))
      matching_target = optional(string, "ANY")
      network_ids     = optional(list(string))
      port            = optional(string)
      zone            = string
    })
  }))
  default = {}

  validation {
    condition = alltrue(flatten([
      for policy in values(var.firewall_policies) : [
        for allow_policy_key in policy.allow_policy_keys_before :
        try(
          var.firewall_policies[allow_policy_key].action == "ALLOW" &&
          var.firewall_policies[allow_policy_key].source.zone == policy.source.zone &&
          var.firewall_policies[allow_policy_key].destination.zone == policy.destination.zone,
          false,
        )
      ]
    ]))
    error_message = "Every allow_policy_keys_before entry must identify an ALLOW policy in the same source and destination zone pair."
  }

  validation {
    condition = alltrue([
      for policy in values(var.firewall_policies) :
      policy.action != "ALLOW" || length(policy.allow_policy_keys_before) == 0
    ])
    error_message = "allow_policy_keys_before can only be set on BLOCK or REJECT policies."
  }
}
