locals {
  #  https://api.webgazer.io/ip-addresses
  webgazer_ip_raw = split("\n", chomp(file("${path.module}/ip/webgazer.txt")))
  webgazer_ip_addresses = [
    for ip in local.webgazer_ip_raw :
    format("%s/%s", trimspace(trimprefix(ip, "\r")), strcontains(ip, ".") ? "32" : "128")
  ]
}

resource "cloudflare_zero_trust_access_policy" "webgazer" {
  account_id = data.cloudflare_account.account.account_id
  name       = "WebGazer IP List"
  decision   = "bypass"

  include = [
    {
      ip_list = {
        id = cloudflare_zero_trust_list.webgazer.id
      }
    }
  ]
}

resource "cloudflare_zero_trust_list" "webgazer" {
  account_id = data.cloudflare_account.account.account_id
  name       = "WebGazer IP List"
  type       = "IP"

  items = [
    for ip in local.webgazer_ip_addresses : {
      value = ip
    }
  ]
}
