output "cname" {
  value     = cloudflare_zero_trust_tunnel_cloudflared.this.cname
  sensitive = true
}
