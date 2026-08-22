include {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_parent_terragrunt_dir()}//modules/aws-dynamodb"
}

# Provisioned, like prod, so dev can exercise onScaleUp. That calls UpdateTable
# with a provisioned throughput, which DynamoDB rejects on an on-demand table.
# Capacity stays at the module minimum of 1, inside the always-free allowance,
# with a ceiling of 10 so autoscaling can return the table to 1 afterwards.
inputs = {
  tables = {
    chatIds = {
      attributes          = [{ name = "chatId", type = "N" }, ]
      autoscaling_enabled = true
      autoscaling_read    = { max_capacity = 10 }
      autoscaling_write   = { max_capacity = 10 }
      billing_mode        = "PROVISIONED"
      hash_key            = "chatId"
      name                = "jung2bot-dev-chatIds"
    }
    messages = {
      attributes          = [{ name = "chatId", type = "N" }, { name = "dateCreated", type = "S" }]
      autoscaling_enabled = true
      autoscaling_read    = { max_capacity = 10 }
      autoscaling_write   = { max_capacity = 10 }
      billing_mode        = "PROVISIONED"
      hash_key            = "chatId"
      name                = "jung2bot-dev-messages"
      range_key           = "dateCreated"
    }
  }
}
