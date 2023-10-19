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

resource "cloudflare_access_policy" "aws" {
  application_id = cloudflare_access_application.this.id
  zone_id        = var.zone_id
  name           = "AWS IP List"
  precedence     = "3"
  decision       = "bypass"

  include {
    ip = concat(
      data.aws_ip_ranges.this.cidr_blocks,
      data.aws_ip_ranges.this.ipv6_cidr_blocks
    )
  }
}
