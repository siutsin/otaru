resource "cloudflare_record" "record" {
  for_each = var.records

  name    = each.value["name"]
  proxied = each.value["proxied"]
  ttl     = each.value["ttl"]
  type    = each.value["type"]
  value   = each.value["value"]
  zone_id = var.zone_id
}
