variable "monitor_url" {
  type      = string
  sensitive = true
}

variable "monitor_name" {
  type    = string
  default = "otaru"
}
