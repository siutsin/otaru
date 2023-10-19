variable "health_check_fqdn" {
  type      = string
  sensitive = true
}

variable "name" {
  type = string
}

variable "resource_path" {
  type    = string
  default = "/httpbin/status/200"
}
