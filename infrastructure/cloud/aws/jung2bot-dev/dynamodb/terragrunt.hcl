include {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_parent_terragrunt_dir()}//modules/aws-dynamodb"
}

inputs = {
  tables = {
    chatIds = {
      attributes = [{ name = "chatId", type = "N" }, ]
      hash_key   = "chatId"
      name       = "jung2bot-dev-chatIds"
    }
    messages = {
      attributes = [{ name = "chatId", type = "N" }, { name = "dateCreated", type = "S" }]
      hash_key   = "chatId"
      name       = "jung2bot-dev-messages"
      range_key  = "dateCreated"
    }
  }
}
