variable "oidc_url" {
  type = string
  validation {
    condition     = startswith(var.oidc_url, "https://") && !endswith(var.oidc_url, "/")
    error_message = "The oidc_url must start with 'https://' and must not end with '/' for secure communication."
  }
}

variable "client_id_list" {
  type = list(string)
}

variable "thumbprint_list" {
  type = list(string)
}
