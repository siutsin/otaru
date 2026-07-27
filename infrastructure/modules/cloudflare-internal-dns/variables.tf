variable "zone_id" {
  type      = string
  sensitive = true
}

variable "subdomains" {
  type      = map(string)
  sensitive = true
}

variable "ip" {
  type      = string
  sensitive = true
}
