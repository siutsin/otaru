locals {
  tunnel_hostname = sensitive("${cloudflare_zero_trust_tunnel_cloudflared.this.id}.cfargotunnel.com")
}

resource "cloudflare_dns_record" "public" {
  zone_id = var.zone_id
  content = local.tunnel_hostname
  name    = var.name
  proxied = true
  ttl     = 1
  type    = "CNAME"
}

resource "cloudflare_dns_record" "oidc" {
  zone_id = var.zone_id
  content = local.tunnel_hostname
  name    = "oidc"
  proxied = true
  ttl     = 1
  type    = "CNAME"
}
