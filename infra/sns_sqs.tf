# SNS Topic — receives every processed notification event and fans it out
resource "aws_sns_topic" "notify_topic" {
  name = "${var.project_name}-NotifyTopic"
}

# Email subscription — the demo's fixed recipient for real email delivery.
# NOTE: SNS topic subscriptions are static (set at deploy time). The
# per-request "recipient_email" submitted through the form is stored in
# DynamoDB and included in the email body, but SNS itself always delivers
# to this one subscribed address. Sending to an arbitrary end-user address
# per request would require Amazon SES instead of SNS — see README.
resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.notify_topic.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# SQS Queue — decoupled retry/audit buffer subscribed to the SNS topic.
# Provisioned as an extensibility point (matches the documented
# architecture); this demo does not yet wire up a consumer for it.
resource "aws_sqs_queue" "notify_queue" {
  name = "${var.project_name}-NotifyQueue"
}

resource "aws_sqs_queue_policy" "allow_sns" {
  queue_url = aws_sqs_queue.notify_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "sns.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.notify_queue.arn
      Condition = {
        ArnEquals = { "aws:SourceArn" = aws_sns_topic.notify_topic.arn }
      }
    }]
  })
}

resource "aws_sns_topic_subscription" "sqs" {
  topic_arn = aws_sns_topic.notify_topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.notify_queue.arn
}
