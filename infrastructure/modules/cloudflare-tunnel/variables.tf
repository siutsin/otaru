variable "zone_id" {
  type      = string
  sensitive = true
}

variable "account_id" {
  type      = string
  sensitive = true
}

variable "name" {
  type      = string
  sensitive = true
}

variable "tunnel_secret" {
  type      = string
  sensitive = true
}

variable "config_src" {
  type = string
}

variable "network_cidr" {
  type = string
}

variable "catch_all_service" {
  type = string
}
