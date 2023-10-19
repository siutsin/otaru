data "github_ip_ranges" "this" {}

data "aws_ip_ranges" "this" {
  services = ["route53_healthchecks"]
}
