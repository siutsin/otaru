variable "zone_id" {
  type      = string
  sensitive = true
}

variable "name" {
  type      = string
  sensitive = true
}

variable "domain" {
  type      = string
  sensitive = true
}

variable "type" {
  type    = string
  default = "self_hosted"
}

variable "session_duration" {
  type    = string
  default = "24h"
}

variable "auto_redirect_to_identity" {
  type    = bool
  default = false
}

variable "account_id" {
  type      = string
  sensitive = true
}

variable "ip_list" {
  type      = list(string)
  default   = []
  sensitive = true
}
