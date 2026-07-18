locals {
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl")).locals
  version_vars = read_terragrunt_config(find_in_parent_folders("version.hcl")).locals

  aws_version               = local.version_vars.aws_version
  aws_remote_backend_region = local.region_vars.aws_remote_backend_region
  aws_region                = local.region_vars.aws_region

  b2_version         = local.version_vars.b2_version
  cloudflare_version = local.version_vars.cloudflare_version
  github_version     = local.version_vars.github_version
  unifi_version      = local.version_vars.unifi_version
}

# Configure Terragrunt to use OpenTofu instead of Terraform
terraform_binary = "tofu"

# Provider credentials are read from the process environment (see documentation/secrets.md).
# Do not interpolate secrets into this generate block — they would land in .terragrunt-cache.
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
      source  = "Backblaze/b2"
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
    unifi = {
      source  = "paultyng/unifi"
      version = "${local.unifi_version}"
    }
  }
}

provider "aws" {
  region = "${local.aws_region}"

  default_tags {
    tags = {
      Terraform = "true"
      Source    = "github-otaru"
    }
  }
}

# Credentials: B2_APPLICATION_KEY, B2_APPLICATION_KEY_ID
provider "b2" {}

# Credentials: CLOUDFLARE_API_TOKEN
provider "cloudflare" {}

# Credentials: GITHUB_TOKEN
provider "github" {}

# Credentials: UNIFI_USERNAME, UNIFI_PASSWORD, UNIFI_API
provider "unifi" {}
EOF
}

remote_state {
  backend = "s3"

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = {
    bucket       = "github-otaru-${local.aws_remote_backend_region}-terraform-state"
    key          = "${path_relative_to_include()}/terraform.tfstate"
    region       = local.aws_remote_backend_region
    encrypt      = true
    use_lockfile = true
  }
}

inputs = merge(local.region_vars, local.version_vars)
