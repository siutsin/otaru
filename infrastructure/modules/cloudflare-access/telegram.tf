locals {
  #  https://core.telegram.org/resources/cidr.txt
  telegram_ip_raw       = split("\n", chomp(file("${path.module}/ip/telegram-cidr.txt")))
  telegram_ip_addresses = [for ip in local.telegram_ip_raw : trimspace(trimprefix(ip, "\r"))]
}

resource "cloudflare_zero_trust_access_policy" "telegram" {
  account_id = data.cloudflare_account.account.account_id
  name       = "Telegram IP List"
  decision   = "bypass"

  include = [
    {
      ip_list = {
        id = cloudflare_zero_trust_list.telegram.id
      }
    }
  ]
}

resource "cloudflare_zero_trust_list" "telegram" {
  account_id = data.cloudflare_account.account.account_id
  name       = "Telegram IP List"
  type       = "IP"

  items = [
    for ip in local.telegram_ip_addresses : {
      value = ip
    }
  ]
}
