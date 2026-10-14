variable "account_id" {
  description = "Cloudflare account ID that owns the token."
  type        = string
}

variable "token_id" {
  description = "ID of the existing Workers AI token to import."
  type        = string
}
