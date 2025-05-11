include {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_parent_terragrunt_dir()}//modules/aws-oidc-provider"
}

inputs = {
  oidc_url        = "https://oidc.siutsin.com"
  client_id_list  = ["oidc.siutsin.com"]
  thumbprint_list = ["932bed339aa69212c89375b79304b475490b89a0"]
}
