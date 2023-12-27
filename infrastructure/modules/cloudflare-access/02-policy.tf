locals {
  #  https://uptimerobot.com/help/locations/
  #  https://uptimerobot.com/inc/files/ips/IPv4andIPv6.txt
  uptime_robot_ip_raw       = split("\n", chomp(file("${path.module}/ip/uptime-robot-ipv4-ipv6.txt")))
  uptime_robot_ip_addresses = [
    for ip in local.uptime_robot_ip_raw :
    format("%s/%s", trimspace(trimprefix(ip, "\r")), strcontains(ip, ".") ? "32" : "128")
  ]

  #  https://core.telegram.org/resources/cidr.txt
  telegram_ip_raw       = split("\n", chomp(file("${path.module}/ip/telegram-cidr.txt")))
  telegram_ip_addresses = [for ip in local.telegram_ip_raw : trimspace(trimprefix(ip, "\r"))]
}

resource "cloudflare_access_policy" "this" {
  application_id = cloudflare_access_application.this.id
  zone_id        = var.zone_id
  name           = "Cluster IP List"
  precedence     = "1"
  decision       = "bypass"

  include {
    ip = var.ip_list
  }
}

resource "cloudflare_access_policy" "github" {
  application_id = cloudflare_access_application.this.id
  zone_id        = var.zone_id
  name           = "GitHub IP List"
  precedence     = "2"
  decision       = "bypass"

  include {
    ip = data.github_ip_ranges.this.hooks
  }
}

resource "cloudflare_access_policy" "uptime_robot" {
  application_id = cloudflare_access_application.this.id
  zone_id        = var.zone_id
  name           = "UptimeRobot IP List"
  precedence     = "3"
  decision       = "bypass"

  include {
    ip = local.uptime_robot_ip_addresses
  }
}

resource "cloudflare_access_policy" "telegram" {
  application_id = cloudflare_access_application.this.id
  zone_id        = var.zone_id
  name           = "Telegram IP List"
  precedence     = "4"
  decision       = "bypass"

  include {
    ip = local.telegram_ip_addresses
  }
}
