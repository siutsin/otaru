resource "cloudflare_access_application" "this" {
  zone_id                   = data.cloudflare_zone.this.id
  name                      = var.name
  domain                    = var.domain
  type                      = var.type
  session_duration          = var.session_duration
  auto_redirect_to_identity = var.auto_redirect_to_identity
}
