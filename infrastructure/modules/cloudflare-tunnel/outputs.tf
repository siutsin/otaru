output "cname" {
  value     = "${cloudflare_zero_trust_tunnel_cloudflared.this.id}.cfargotunnel.com"
  sensitive = true
}
