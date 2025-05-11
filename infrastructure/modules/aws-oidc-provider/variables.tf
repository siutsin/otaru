variable "oidc_url" {
  type = string
  validation {
    condition     = startswith(var.oidc_url, "https://") && !endswith(var.oidc_url, "/")
    error_message = "The oidc_url must start with 'https://' and must not end with '/' for secure communication."
  }
}

variable "client_id_list" {
  type = list(string)
  validation {
    condition     = length(var.client_id_list) > 0
    error_message = "The client_id_list must contain at least one client ID."
  }
}

variable "thumbprint_list" {
  type        = list(string)
  description = "List of SHA-1 thumbprints for the OIDC provider's TLS certificate (each must be 40 characters and hexadecimal)"
  validation {
    condition     = alltrue([for thumbprint in var.thumbprint_list : length(thumbprint) == 40])
    error_message = "Each thumbprint in thumbprint_list must be exactly 40 characters long."
  }
}
