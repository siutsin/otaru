variable "account_id" {
  description = "Cloudflare account ID that owns the bucket and Worker."
  type        = string
}

variable "zone_id" {
  description = "Cloudflare zone ID for the Worker custom domain."
  type        = string
}
