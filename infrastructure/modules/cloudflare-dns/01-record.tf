resource "cloudflare_record" "internal_record" {
  for_each = var.internal_records

  name    = each.value["name"]
  proxied = false
  ttl     = 1
  type    = "A"
  value   = each.value["value"]
  zone_id = var.zone_id
}

resource "cloudflare_record" "public_record" {
  name    = var.public_subdomain
  proxied = true
  ttl     = 1
  type    = "CNAME"
  value   = var.public_subdomain_value
  zone_id = var.zone_id
}
