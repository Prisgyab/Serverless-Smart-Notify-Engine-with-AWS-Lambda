data "archive_file" "notify_processor" {
  type        = "zip"
  source_file = "${path.module}/../lambda/notify_processor.py"
  output_path = "${path.module}/build/notify_processor.zip"
}

data "archive_file" "notify_query" {
  type        = "zip"
  source_file = "${path.module}/../lambda/notify_query.py"
  output_path = "${path.module}/build/notify_query.zip"
}

resource "aws_iam_role" "lambda_exec" {
  name = "${var.project_name}-lambda-exec"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "lambda_logs" {
  name = "${var.project_name}-lambda-logs"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = "arn:aws:logs:*:*:*"
    }]
  })
}

resource "aws_iam_role_policy" "lambda_dynamodb" {
  name = "${var.project_name}-lambda-dynamodb"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["dynamodb:PutItem", "dynamodb:Scan"]
      Resource = aws_dynamodb_table.notification_log.arn
    }]
  })
}

resource "aws_iam_role_policy" "lambda_sns" {
  name = "${var.project_name}-lambda-sns"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sns:Publish"
      Resource = aws_sns_topic.notify_topic.arn
    }]
  })
}

resource "aws_lambda_function" "notify_processor" {
  function_name    = "${var.project_name}-NotifyProcessor"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "notify_processor.handler"
  runtime          = "python3.12"
  timeout          = 10
  filename         = data.archive_file.notify_processor.output_path
  source_code_hash = data.archive_file.notify_processor.output_base64sha256

  environment {
    variables = {
      NOTIFICATIONS_TABLE = aws_dynamodb_table.notification_log.name
      SNS_TOPIC_ARN        = aws_sns_topic.notify_topic.arn
    }
  }
}

resource "aws_lambda_function" "notify_query" {
  function_name    = "${var.project_name}-NotifyQuery"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "notify_query.handler"
  runtime          = "python3.12"
  timeout          = 10
  filename         = data.archive_file.notify_query.output_path
  source_code_hash = data.archive_file.notify_query.output_base64sha256

  environment {
    variables = {
      NOTIFICATIONS_TABLE = aws_dynamodb_table.notification_log.name
    }
  }
}
