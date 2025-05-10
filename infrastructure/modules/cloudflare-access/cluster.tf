resource "cloudflare_zero_trust_access_policy" "cluster" {
  account_id = data.cloudflare_account.account.account_id
  name       = "Cluster IP List"
  decision   = "bypass"

  include = [
    {
      ip_list = {
        id = cloudflare_zero_trust_list.cluster.id
      }
    }
  ]
}

resource "cloudflare_zero_trust_list" "cluster" {
  account_id = data.cloudflare_account.account.account_id
  name       = "Cluster IP List"
  type       = "IP"

  items = [
    for ip in var.ip_list : {
      value = ip
    }
  ]
}
