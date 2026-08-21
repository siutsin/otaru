variable "zone_id" {
  type      = string
  sensitive = true
}

variable "subdomains" {
  type = map(object({
    name = string
    ip   = string
  }))
  sensitive = true
}
