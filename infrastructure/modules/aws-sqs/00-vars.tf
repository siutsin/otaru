variable "sqss" {
  type = map(object({
    name                       = string
    fifo                       = optional(bool, false)
    visibility_timeout_seconds = optional(number)
  }))
}
