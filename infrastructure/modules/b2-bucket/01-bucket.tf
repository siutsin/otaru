resource "b2_bucket" "this" {
  for_each = var.buckets

  bucket_name = each.key
  bucket_type = each.value.bucket_type

  default_server_side_encryption {
    algorithm = each.value.default_server_side_encryption.algorithm
    mode      = each.value.default_server_side_encryption.mode
  }

  dynamic "lifecycle_rules" {
    for_each = each.value.lifecycle_rules
    content {
      file_name_prefix              = lifecycle_rules.value.file_name_prefix
      days_from_hiding_to_deleting  = lifecycle_rules.value.days_from_hiding_to_deleting
      days_from_uploading_to_hiding = lifecycle_rules.value.days_from_uploading_to_hiding
    }
  }
}
