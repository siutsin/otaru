variable "zone" {
  type      = string
  sensitive = true
}

variable "zone_id" {
  type      = string
  sensitive = true
}

variable "records" {
  type = map(object({
    name    = string
    proxied = bool
    ttl     = number
    type    = string
    value   = string
  }))
  default = {}
}
