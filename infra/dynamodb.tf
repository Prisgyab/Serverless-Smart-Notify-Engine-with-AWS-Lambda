resource "aws_dynamodb_table" "notification_log" {
  name         = "${var.project_name}-NotificationLog"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "notification_id"

  attribute {
    name = "notification_id"
    type = "S"
  }

  tags = {
    Name = "${var.project_name}-NotificationLog"
  }
}
