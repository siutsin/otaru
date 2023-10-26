data "uptimerobot_account" "this" {}

data "uptimerobot_alert_contact" "this" {
  friendly_name = data.uptimerobot_account.this.email
}

resource "uptimerobot_monitor" "this" {
  friendly_name = var.monitor_name
  type          = "http"
  url           = var.monitor_url

  alert_contact {
    id = data.uptimerobot_alert_contact.this.id
  }
}
