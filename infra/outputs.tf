output "api_base_url" {
  description = "Base URL for the API — set this as API_BASE in index.html before deploying it"
  value       = aws_api_gateway_stage.prod.invoke_url
}

output "frontend_website_url" {
  description = "S3 static website URL for the dashboard"
  value       = aws_s3_bucket_website_configuration.frontend.website_endpoint
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.notification_log.name
}

output "sns_topic_arn" {
  value = aws_sns_topic.notify_topic.arn
}

output "sqs_queue_url" {
  value = aws_sqs_queue.notify_queue.id
}
