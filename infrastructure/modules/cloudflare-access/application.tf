resource "cloudflare_zero_trust_access_application" "this" {
  zone_id                   = var.zone_id
  name                      = var.name
  domain                    = var.domain
  type                      = var.type
  session_duration          = var.session_duration
  auto_redirect_to_identity = var.auto_redirect_to_identity
  # Binds the auth cookie to the client, hardening against compromised
  # authorization tokens and CSRF attacks (Cloudflare-recommended).
  enable_binding_cookie = true
  # No cross-origin CORS preflight requirement for this application; keep
  # OPTIONS requests behind Access rather than bypassing auth for them.
  options_preflight_bypass = false

  policies = [
    {
      id         = cloudflare_zero_trust_access_policy.cluster.id
      precedence = 1
    },
    {
      id         = cloudflare_zero_trust_access_policy.github.id
      precedence = 2
    },
    {
      id         = cloudflare_zero_trust_access_policy.webgazer.id
      precedence = 3
    },
    {
      id         = cloudflare_zero_trust_access_policy.telegram.id
      precedence = 4
    }
  ]
}
