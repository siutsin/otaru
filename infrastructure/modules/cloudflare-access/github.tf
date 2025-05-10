data "github_ip_ranges" "github_ip" {}

resource "cloudflare_zero_trust_access_policy" "github" {
  account_id = data.cloudflare_account.account.account_id
  name       = "GitHub IP List"
  decision   = "bypass"

  include = [
    {
      ip_list = {
        id = cloudflare_zero_trust_list.github.id
      }
    }
  ]
}

resource "cloudflare_zero_trust_list" "github" {
  account_id = data.cloudflare_account.account.account_id
  name       = "GitHub IP List"
  type       = "IP"

  items = [
    for ip in data.github_ip_ranges.github_ip.hooks : {
      value = ip
    }
  ]
}
