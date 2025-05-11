include {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_parent_terragrunt_dir()}//modules/aws-oidc-provider"
}

inputs = {
  url             = "https://oidc.siutsin.com"
  client_id_list  = ["oidc.siutsin.com"]
}
