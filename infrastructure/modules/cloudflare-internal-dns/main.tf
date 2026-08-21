resource "cloudflare_dns_record" "this" {
  for_each = nonsensitive(toset(keys(var.subdomains)))

  zone_id = var.zone_id
  name    = var.subdomains[each.key].name
  content = var.subdomains[each.key].ip
  proxied = false
  ttl     = 1
  type    = "A"
}
