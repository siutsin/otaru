include {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_parent_terragrunt_dir()}//modules/b2-bucket"
}

inputs = {
  buckets = {
    "github-otaru-media-storage"         = {}
    "github-otaru-cloudnative-pg-backup" = {}
  }
}
