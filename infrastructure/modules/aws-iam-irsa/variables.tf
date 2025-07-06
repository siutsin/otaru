variable "name" {
  type = string
}

variable "oidc_provider" {
  type = string
}

variable "service_account" {
  type = string
}

variable "role_policies" {
  type = map(object({
    actions   = list(string)
    resources = list(string)
  }))
}
