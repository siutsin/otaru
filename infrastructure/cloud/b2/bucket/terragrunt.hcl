include {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_parent_terragrunt_dir()}//modules/b2-bucket"
}

locals {
  media_storage_bucket = get_env("B2_MEDIA_STORAGE_BUCKET", "")
  cnpg_backup_bucket   = get_env("B2_CNPG_BACKUP_BUCKET", "")
}

inputs = {
  buckets = {
    (local.media_storage_bucket) = {}
    (local.cnpg_backup_bucket)   = {}
  }
}
