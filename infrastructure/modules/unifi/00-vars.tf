variable "device_gateway" {
  type = map(object({
    name = string
  }))
}

variable "device_switch" {
  type = map(object({
    name = string
  }))
}

variable "device_wifi" {
  type = map(object({
    name = string
  }))
}

variable "wan" {
  type = map(object({
    name             = string
    purpose          = string
    wan_dns          = list(string)
    wan_networkgroup = string
    wan_type         = string
    wan_type_v6      = string
  }))
}
