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
  is_default_network = false

  lifecycle {
    # Cloudflare v5 keeps the deprecated is_default=false value in legacy
    # state; ignoring only that removed input avoids replacing the network and
    # its route while is_default_network remains the configured source of truth.
    ignore_changes = [is_default]
  }
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
        origin_request = {
          origin_server_name = "${var.name}.${var.zone}"
          http2_origin       = true
        }
      },
      {
        hostname = "analytics.${var.zone}"
        service  = var.gateway_service
        origin_request = {
          origin_server_name = "analytics.${var.zone}"
          http2_origin       = true
        }
      },
      {
        # Hydra's public OAuth and discovery endpoints use the shared gateway;
        # its administrative Service has no HTTPRoute and remains inaccessible.
        hostname = "auth.${var.zone}"
        service  = var.gateway_service
        origin_request = {
          origin_server_name = "auth.${var.zone}"
          http2_origin       = true
        }
      },
      {
        service = "http_status:404"
      }
    ]
  }
}
