variable "zone" {
  type = string
}

variable "name" {
  type = string
}

variable "domain" {
  type = string
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

variable "ip_list" {
  type    = list(string)
  default = []
}
