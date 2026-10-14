data "cloudflare_account_api_token_permission_groups_list" "this" {
  account_id = var.account_id
}

locals {
  permission_groups = {
    for group in data.cloudflare_account_api_token_permission_groups_list.this.result :
    group.name => group.id
  }
}

# Imported only; the token value stays in the vault.
import {
  to = cloudflare_api_token.jev
  id = var.token_id
}

resource "cloudflare_api_token" "jev" {
  name = "jev-workers-ai"

  policies = [{
    effect = "allow"
    permission_groups = [
      { id = local.permission_groups["Workers AI Read"] },
      { id = local.permission_groups["Workers AI Edit"] },
    ]
    resources = {
      "com.cloudflare.api.account.${var.account_id}" = "*"
    }
  }]
}
