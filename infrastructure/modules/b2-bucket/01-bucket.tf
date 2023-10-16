resource "b2_bucket" "this" {
  bucket_name = var.bucket_name
  bucket_type = var.bucket_type

  default_server_side_encryption {
    algorithm = "AES256"
    mode      = "SSE-B2"
  }

  lifecycle {
    // B2 terraform provider is buggy. Use web UI to change the following
    ignore_changes = [
      file_lock_configuration,
      lifecycle_rules
    ]
  }
}
