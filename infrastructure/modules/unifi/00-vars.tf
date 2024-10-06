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
