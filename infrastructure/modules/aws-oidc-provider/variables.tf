variable "oidc_url" {
  type = string
  validation {
    condition     = startswith(var.oidc_url, "https://")
    error_message = "The oidc_url must start with 'https://' for secure communication."
  }
}

variable "client_id_list" {
  type = list(string)
}

variable "thumbprint_list" {
  type = list(string)
}
