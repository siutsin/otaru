resource "cloudflare_tunnel" "this" {
  account_id = var.account_id
  name       = var.name
  secret     = var.secret
}
