resource "cloudflare_zero_trust_access_application" "this" {
  zone_id                   = var.zone_id
  name                      = var.name
  domain                    = var.domain
  type                      = var.type
  session_duration          = var.session_duration
  auto_redirect_to_identity = var.auto_redirect_to_identity
}
