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
      default_server_side_encryption = {
        algorithm = "AES256"
        mode = "SSE-B2"
      }
      lifecycle_rules = [
        {
          file_name_prefix = "temp/"
          days_from_hiding_to_deleting = 7
          days_from_uploading_to_hiding = 1
        }
      ]
    }
    "minimal-bucket" = {}
  }
}
```

## Variables

| Name    | Description                                                                                      | Type                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 | Default | Required |
|---------|--------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------|:--------:|
| buckets | Map of bucket configurations where the key is the bucket name and value contains bucket settings | `map(object({bucket_type = optional(string, "allPrivate"), default_server_side_encryption = optional(object({algorithm = optional(string, "AES256"), mode = optional(string, "SSE-B2")}), {algorithm = "AES256", mode = "SSE-B2"}), lifecycle_rules = optional(list(object({file_name_prefix = optional(string, ""), days_from_hiding_to_deleting = optional(number, 1), days_from_uploading_to_hiding = optional(number, 0)})), [{file_name_prefix = "", days_from_hiding_to_deleting = 1, days_from_uploading_to_hiding = 0}])}))` | n/a     |   yes    |

### Bucket Configuration Options

Each bucket in the `buckets` map can have the following optional settings:

#### `bucket_type`

- **Type**: `string`
- **Default**: `"allPrivate"`
- **Description**: The type of bucket (e.g., "allPrivate", "allPublic")

#### `default_server_side_encryption`

- **Type**: `object`
- **Default**: `{algorithm = "AES256", mode = "SSE-B2"}`
- **Description**: Server-side encryption configuration
  - `algorithm`: Encryption algorithm (default: "AES256")
  - `mode`: Encryption mode (default: "SSE-B2")

#### `lifecycle_rules`

- **Type**: `list(object)`
- **Default**: `[{file_name_prefix = "", days_from_hiding_to_deleting = 1, days_from_uploading_to_hiding = 0}]`
- **Description**: List of lifecycle rules for the bucket
  - `file_name_prefix`: Prefix for files to apply the rule to (default: "")
  - `days_from_hiding_to_deleting`: Days from hiding to deleting (default: 1)
  - `days_from_uploading_to_hiding`: Days from uploading to hiding (default: 0)

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
