module "dynamodb_table" {
  source  = "terraform-aws-modules/dynamodb-table/aws"
  version = "~> 5.0"

  for_each = var.tables

  attributes          = each.value.attributes
  autoscaling_enabled = each.value.autoscaling_enabled
  autoscaling_read    = each.value.autoscaling_read
  autoscaling_write   = each.value.autoscaling_write
  billing_mode        = each.value.billing_mode
  hash_key            = each.value.hash_key
  name                = each.value.name
  range_key           = each.value.range_key
  read_capacity       = each.value.billing_mode == "PROVISIONED" ? 1 : null
  write_capacity      = each.value.billing_mode == "PROVISIONED" ? 1 : null

  point_in_time_recovery_enabled = true
  stream_enabled                 = true
  stream_view_type               = "NEW_AND_OLD_IMAGES"
  ttl_attribute_name             = "ttl"
  ttl_enabled                    = true

  timeouts = {
    update = "1h"
  }
}
