# b2-bucket

Terraform module for creating Backblaze B2 buckets with support for multiple buckets.

## Usage

```hcl
module "b2_buckets" {
  source = "../../modules/b2-bucket"
  
  buckets = {
    "backup-storage" = {
      bucket_type = "allPrivate"
    }
    "public-assets" = {
      bucket_type = "allPublic"
    }
  }
}
```

## Variables

| Name    | Description                                                                                      | Type                                                          | Default | Required |
|---------|--------------------------------------------------------------------------------------------------|---------------------------------------------------------------|---------|:--------:|
| buckets | Map of bucket configurations where the key is the bucket name and value contains bucket settings | `map(object({bucket_type = optional(string, "allPrivate")}))` | n/a     |   yes    |

## Outputs

| Name         | Description                                  |
|--------------|----------------------------------------------|
| buckets      | Map of created B2 buckets with their details |
| bucket_ids   | Map of bucket names to their IDs             |
| bucket_names | List of created bucket names                 |

## Import a B2 bucket

```shell
terragrunt import b2_bucket.this["bucket-name"] {bucket_id}
```
