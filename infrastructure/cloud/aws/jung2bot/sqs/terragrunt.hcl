include {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_parent_terragrunt_dir()}//modules/aws-sqs"
}

inputs = {
  sqss = {
    event = {
      name = "jung2bot-prod-event-queue"
    }
  }
}
