resource "aws_iam_openid_connect_provider" "this" {
  url             = var.url
  client_id_list  = var.client_id_list
}
