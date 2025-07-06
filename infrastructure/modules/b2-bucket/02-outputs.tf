output "buckets" {
  description = "Map of created B2 buckets with their details"
  value = {
    for bucket_name, bucket in b2_bucket.this : bucket_name => {
      id          = bucket.id
      bucket_name = bucket.bucket_name
      bucket_type = bucket.bucket_type
    }
  }
}

output "bucket_ids" {
  description = "Map of bucket names to their IDs"
  value = {
    for bucket_name, bucket in b2_bucket.this : bucket_name => bucket.id
  }
}

output "bucket_names" {
  description = "List of created bucket names"
  value       = keys(b2_bucket.this)
}
