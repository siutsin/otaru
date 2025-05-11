locals {
  tunnel_hostname = sensitive("${cloudflare_zero_trust_tunnel_cloudflared.this.id}.cfargotunnel.com")
}

resource "cloudflare_dns_record" "this" {
  zone_id = var.zone_id
  content = local.tunnel_hostname
  name    = var.name
  proxied = true
  ttl     = 1
  type    = "CNAME"
}
