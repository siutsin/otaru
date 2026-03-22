resource "cloudflare_dns_record" "this" {
  count = length(var.subdomains)

  zone_id = var.zone_id
  name    = var.subdomains[count.index]
  content = var.ip
  proxied = false
  ttl     = 1
  type    = "A"
}
