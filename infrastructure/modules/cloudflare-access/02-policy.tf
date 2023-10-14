resource "cloudflare_access_policy" "this" {
  application_id = cloudflare_access_application.this.id
  zone_id        = data.cloudflare_zone.this.id
  name           = "IP List"
  precedence     = "1"
  decision       = "bypass"

  include {
    ip = concat(
      var.ip_list,
      data.github_ip_ranges.this.hooks
    )
  }
}
