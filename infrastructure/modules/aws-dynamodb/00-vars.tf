variable "tables" {
  type = map(object({
    attributes          = list(object({ name = string, type = string }))
    autoscaling_enabled = optional(bool, false)
    autoscaling_read    = optional(object({ max_capacity = optional(string) }), {})
    autoscaling_write   = optional(object({ max_capacity = optional(string) }), {})
    billing_mode        = optional(string, "PAY_PER_REQUEST")
    hash_key            = string
    name                = string
    range_key           = optional(string)
  }))
}
