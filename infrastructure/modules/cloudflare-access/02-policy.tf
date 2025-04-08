locals {
  #  https://api.webgazer.io/ip-addresses
  webgazer_ip_raw = split("\n", chomp(file("${path.module}/ip/webgazer.txt")))
  webgazer_ip_addresses = [
    for ip in local.webgazer_ip_raw :
    format("%s/%s", trimspace(trimprefix(ip, "\r")), strcontains(ip, ".") ? "32" : "128")
  ]

  #  https://core.telegram.org/resources/cidr.txt
  telegram_ip_raw       = split("\n", chomp(file("${path.module}/ip/telegram-cidr.txt")))
  telegram_ip_addresses = [for ip in local.telegram_ip_raw : trimspace(trimprefix(ip, "\r"))]
}

resource "cloudflare_zero_trust_access_policy" "this" {
  application_id = cloudflare_zero_trust_access_application.this.id
  zone_id        = var.zone_id
  name           = "Cluster IP List"
  precedence     = "1"
  decision       = "bypass"

  include {
    ip = var.ip_list
  }
}

resource "cloudflare_zero_trust_access_policy" "github" {
  application_id = cloudflare_zero_trust_access_application.this.id
  zone_id        = var.zone_id
  name           = "GitHub IP List"
  precedence     = "2"
  decision       = "bypass"

  include {
    ip = data.github_ip_ranges.github_ip.hooks
  }
}

resource "cloudflare_zero_trust_access_policy" "webgazer" {
  application_id = cloudflare_zero_trust_access_application.this.id
  zone_id        = var.zone_id
  name           = "WebGazer IP List"
  precedence     = "3"
  decision       = "bypass"

  include {
    ip = local.webgazer_ip_addresses
  }
}

resource "cloudflare_zero_trust_access_policy" "telegram" {
  application_id = cloudflare_zero_trust_access_application.this.id
  zone_id        = var.zone_id
  name           = "Telegram IP List"
  precedence     = "4"
  decision       = "bypass"

  include {
    ip = local.telegram_ip_addresses
  }
}
