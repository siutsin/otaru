locals {
  aws_remote_backend_region = "eu-west-1"
  aws_default_region        = "eu-west-1"

  cloudflare_api_token           = "abcd...."
  cloudflare_account_id          = "abcd...."
  cloudflare_zone                = "example.com"
  cloudflare_zone_subdomain      = "subdomain"
  cloudflare_zone_tunnel_cname   = "<uuid>.cfargotunnel.com"
  cloudflare_zone_tunnel_ip_list = [
    "1.2.3.4/32"
  ]
}
