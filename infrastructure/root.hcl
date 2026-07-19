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

  # Scope required_providers to the unit path so each stack only pulls what it uses.
  unit_path = path_relative_to_include()

  needs_aws        = startswith(local.unit_path, "cloud/aws/")
  needs_b2         = startswith(local.unit_path, "cloud/b2/")
  needs_cloudflare = startswith(local.unit_path, "cloud/cloudflare/")
  # GitHub IP ranges data source is only used by Access.
  needs_github = startswith(local.unit_path, "cloud/cloudflare/access")
  needs_unifi  = startswith(local.unit_path, "local/")

  required_providers_hcl = join("\n", compact([
    local.needs_aws ? <<-EOT
    aws = {
      source  = "hashicorp/aws"
      version = "${local.aws_version}"
    }
    EOT
    : "",
    local.needs_b2 ? <<-EOT
    b2 = {
      source  = "Backblaze/b2"
      version = "${local.b2_version}"
    }
    EOT
    : "",
    local.needs_cloudflare ? <<-EOT
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "${local.cloudflare_version}"
    }
    EOT
    : "",
    local.needs_github ? <<-EOT
    github = {
      source  = "integrations/github"
      version = "${local.github_version}"
    }
    EOT
    : "",
    local.needs_unifi ? <<-EOT
    unifi = {
      source  = "ubiquiti-community/unifi"
      version = "${local.unifi_version}"
    }
    EOT
    : "",
  ]))

  provider_blocks_hcl = join("\n", compact([
    local.needs_aws ? <<-EOT
provider "aws" {
  region = "${local.aws_region}"

  default_tags {
    tags = {
      Terraform = "true"
      Source    = "github-otaru"
    }
  }
}
EOT
    : "",
    # Credentials: B2_APPLICATION_KEY, B2_APPLICATION_KEY_ID
    local.needs_b2 ? "provider \"b2\" {}" : "",
    # Credentials: CLOUDFLARE_API_TOKEN
    local.needs_cloudflare ? "provider \"cloudflare\" {}" : "",
    # Credentials: GITHUB_TOKEN
    local.needs_github ? "provider \"github\" {}" : "",
    # Credentials: UNIFI_USERNAME, UNIFI_PASSWORD, UNIFI_API
    local.needs_unifi ? "provider \"unifi\" {}" : "",
  ]))
}

# Configure Terragrunt to use OpenTofu instead of Terraform
terraform_binary = "tofu"

# Provider credentials are read from the process environment (see documentation/secrets.md).
# Do not interpolate secrets into this generate block — they would land in .terragrunt-cache.
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite"
  contents  = <<-EOF
terraform {
  required_providers {
${local.required_providers_hcl}
  }
}

${local.provider_blocks_hcl}
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
