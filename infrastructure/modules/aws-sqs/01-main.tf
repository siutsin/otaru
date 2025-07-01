data "aws_caller_identity" "current" {}

module "sqs" {
  source  = "terraform-aws-modules/sqs/aws"
  version = "~> 5.0"

  for_each = var.sqss

  name                              = each.value.name
  visibility_timeout_seconds        = 600
  kms_master_key_id                 = "alias/aws/sqs"
  kms_data_key_reuse_period_seconds = 86400
}

resource "aws_sqs_queue_policy" "this" {
  for_each = module.sqs

  queue_url = each.value.queue_id

  policy = <<EOF
  {
    "Version": "2008-10-17",
    "Id": " policy",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "AWS": [
            "${data.aws_caller_identity.current.account_id}"
          ]
        },
        "Action": [
          "SQS:*"
        ],
        "Resource": "${each.value.queue_arn}"
      }
    ]
  }
  EOF
}
