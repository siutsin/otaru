include {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_parent_terragrunt_dir()}//modules/aws-dynamodb"
}

inputs = {
  tables = {
    chatIds = {
      attributes          = [{ name = "chatId", type = "N" }, ]
      autoscaling_enabled = true
      autoscaling_read    = { max_capacity = 1000 }
      autoscaling_write   = { max_capacity = 1000 }
      billing_mode        = "PROVISIONED"
      hash_key            = "chatId"
      name                = "jung2bot-prod-chatIds"
    }
    messages = {
      attributes          = [{ name = "chatId", type = "N" }, { name = "dateCreated", type = "S" }]
      autoscaling_enabled = true
      autoscaling_read    = { max_capacity = 1000 }
      autoscaling_write   = { max_capacity = 1000 }
      billing_mode        = "PROVISIONED"
      hash_key            = "chatId"
      name                = "jung2bot-prod-messages"
      range_key           = "dateCreated"
    }
  }
}
