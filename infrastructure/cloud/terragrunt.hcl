locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  version_vars = read_terragrunt_config(find_in_parent_folders("version.hcl"))

  aws_version               = local.version_vars.locals.aws_version
  aws_remote_backend_region = local.account_vars.locals.aws_remote_backend_region
  aws_default_region        = local.account_vars.locals.aws_default_region

  cloudflare_version   = local.version_vars.locals.cloudflare_version
  cloudflare_api_token = local.account_vars.locals.cloudflare_api_token

  github_version = local.version_vars.locals.github_version
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
  region  = "${local.aws_default_region}"

  default_tags {
    tags = {
      Terraform = "true"
      Source    = "github-otaru"
    }
  }
}

provider "cloudflare" {
  api_token = "${local.cloudflare_api_token}"
}

provider "github" {}
EOF
}

remote_state {
  backend = "s3"

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = {
    bucket  = "github-otaru-${local.aws_remote_backend_region}-terraform-state"
    key     = "${path_relative_to_include()}/terraform.tfstate"
    region  = local.aws_remote_backend_region
    encrypt = true
  }
}

inputs = merge(local.account_vars.locals, local.version_vars.locals)
