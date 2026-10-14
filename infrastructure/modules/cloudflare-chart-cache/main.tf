resource "cloudflare_r2_bucket" "charts" {
  account_id = var.account_id
  name       = "helm-charts"
}

resource "cloudflare_workers_script" "chart_cache" {
  account_id         = var.account_id
  script_name        = "chart-cache"
  content_file       = "${path.module}/worker.js"
  content_sha256     = filesha256("${path.module}/worker.js")
  main_module        = "worker.js"
  compatibility_date = "2026-10-01"

  bindings = [{
    name        = "CHARTS"
    type        = "r2_bucket"
    bucket_name = cloudflare_r2_bucket.charts.name
  }]
}

# The custom domain is the only public endpoint.
resource "cloudflare_workers_script_subdomain" "chart_cache" {
  account_id       = var.account_id
  script_name      = cloudflare_workers_script.chart_cache.script_name
  enabled          = false
  previews_enabled = false
}

resource "cloudflare_workers_custom_domain" "charts" {
  account_id = var.account_id
  zone_id    = var.zone_id
  hostname   = "charts.siutsin.com"
  service    = cloudflare_workers_script.chart_cache.script_name
}
