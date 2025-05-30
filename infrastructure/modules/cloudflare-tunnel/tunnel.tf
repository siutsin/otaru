resource "cloudflare_zero_trust_tunnel_cloudflared" "this" {
  account_id    = var.account_id
  name          = var.name
  config_src    = var.config_src
  tunnel_secret = var.tunnel_secret
}

resource "cloudflare_zero_trust_tunnel_cloudflared_virtual_network" "this" {
  account_id         = var.account_id
  name               = var.name
  comment            = var.name
  is_default         = false
  is_default_network = false
}

resource "cloudflare_zero_trust_tunnel_cloudflared_route" "this" {
  account_id         = var.account_id
  network            = var.network_cidr
  tunnel_id          = cloudflare_zero_trust_tunnel_cloudflared.this.id
  comment            = cloudflare_zero_trust_tunnel_cloudflared_virtual_network.this.name
  virtual_network_id = cloudflare_zero_trust_tunnel_cloudflared_virtual_network.this.id
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "this" {
  account_id = var.account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.this.id
  source     = var.config_src
  config = {
    ingress = [
      {
        hostname = "oidc.${var.zone}"
        service  = var.kubernetes_service
        path     = "/.well-known/openid-configuration"
        origin_request = {
          ca_pool = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
        }
      },
      {
        hostname = "oidc.${var.zone}"
        service  = var.kubernetes_service
        path     = "/openid/v1/jwks"
        origin_request = {
          ca_pool = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
        }
      },
      {
        hostname = "${var.name}.${var.zone}"
        service  = var.gateway_service
      },
      {
        service = "http_status:404"
      }
    ]
  }
}
