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
      # Telegram client timeout is 10s. Keep the message hidden for 60s
      # while that call is still open.
      visibility_timeout_seconds = 60
    }
    message_save = {
      name = "jung2bot-prod-message-save-queue.fifo"
      fifo = true
      # Flush interval is 10s. Visibility must last the whole batch.
      visibility_timeout_seconds = 30
    }
  }
}
