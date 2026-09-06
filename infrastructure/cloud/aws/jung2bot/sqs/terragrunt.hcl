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
    message_save = {
      name = "jung2bot-prod-message-save-queue.fifo"
      fifo = true
      # Flush interval is 10s. Visibility must last the whole batch.
      visibility_timeout_seconds = 30
    }
  }
}
