include {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_parent_terragrunt_dir()}//modules/b2-bucket"
}

locals {
  tfconfig             = jsondecode(file(get_env("OTARU_TF_CONFIG_FILE")))
  media_storage_bucket = local.tfconfig.b2.bucket.media_storage
  cnpg_backup_bucket   = local.tfconfig.b2.bucket.cnpg_backup
}

inputs = {
  buckets = {
    (local.media_storage_bucket) = {}
    (local.cnpg_backup_bucket)   = {}
  }
}
