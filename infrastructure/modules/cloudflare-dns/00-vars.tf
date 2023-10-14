variable "zone" {
  type      = string
  sensitive = true
}

variable "zone_id" {
  type      = string
  sensitive = true
}

variable "public_subdomain" {
  type      = string
  sensitive = true
}

variable "public_subdomain_value" {
  type      = string
  sensitive = true
}

variable "internal_records" {
  type = map(object({
    name  = string
    value = string
  }))
}
