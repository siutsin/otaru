output "cname" {
  value     = cloudflare_tunnel.this.cname
  sensitive = true
}
