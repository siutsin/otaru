locals {
  project_vars = read_terragrunt_config(find_in_parent_folders("project.hcl")).locals
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl")).locals
  version_vars = read_terragrunt_config(find_in_parent_folders("version.hcl")).locals

  project_name = local.project_vars.name

  aws_version               = local.version_vars.aws_version
  aws_remote_backend_region = local.region_vars.aws_remote_backend_region
  aws_region                = local.region_vars.aws_region

  b2_version            = local.version_vars.b2_version
  b2_application_key    = get_env("B2_APPLICATION_KEY")
  b2_application_key_id = get_env("B2_APPLICATION_KEY_ID")

  cloudflare_version   = local.version_vars.cloudflare_version
  cloudflare_api_token = get_env("CLOUDFLARE_API_TOKEN")

  github_token   = get_env("GITHUB_TOKEN")
  github_version = local.version_vars.github_version
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents  = <<EOF
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "${local.aws_version}"
    }
    b2 = {
      source = "Backblaze/b2"
      version = "${local.b2_version}"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "${local.cloudflare_version}"
    }
    github = {
      source  = "integrations/github"
      version = "${local.github_version}"
    }
  }
}

provider "aws" {
  region  = "${local.aws_region}"

  default_tags {
    tags = {
      Terraform = "true"
      Source    = "${local.project_name}"
    }
  }
}

provider "b2" {
  application_key    = "${local.b2_application_key}"
  application_key_id = "${local.b2_application_key_id}"
}

provider "cloudflare" {
  api_token = "${local.cloudflare_api_token}"
}

provider "github" {
  token = "${local.github_token}"
}
EOF
}

remote_state {
  backend = "s3"

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = {
    bucket  = "${local.project_name}-${local.aws_remote_backend_region}-terraform-state"
    key     = "${path_relative_to_include()}/terraform.tfstate"
    region  = local.aws_remote_backend_region
    encrypt = true
  }
}

inputs = merge(local.region_vars, local.version_vars)
