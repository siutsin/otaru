data "cloudflare_zone" "this" {
  name = var.zone
}

data "github_ip_ranges" "this" {}
