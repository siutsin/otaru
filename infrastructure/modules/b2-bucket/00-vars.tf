variable "buckets" {
  description = "Map of bucket configurations where the key is the bucket name and value contains bucket settings"
  type = map(object({
    bucket_type = optional(string, "allPrivate")
    default_server_side_encryption = optional(object({
      algorithm = optional(string, "AES256")
      mode      = optional(string, "SSE-B2")
      }), {
      algorithm = "AES256"
      mode      = "SSE-B2"
    })
    lifecycle_rules = optional(list(object({
      file_name_prefix              = optional(string, "")
      days_from_hiding_to_deleting  = optional(number, 1)
      days_from_uploading_to_hiding = optional(number, 0)
      })), [
      {
        file_name_prefix              = ""
        days_from_hiding_to_deleting  = 1
        days_from_uploading_to_hiding = 0
      }
    ])
  }))

  validation {
    condition = alltrue([
      for bucket_name, config in var.buckets :
      can(regex("^[a-z0-9-]+$", bucket_name))
    ])
    error_message = "Bucket names must contain only lowercase letters, numbers, and hyphens."
  }
}
