resource "aws_api_gateway_rest_api" "api" {
  name = "${var.project_name}-api"
}

# ---- /notify (POST) ----

resource "aws_api_gateway_resource" "notify" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "notify"
}

resource "aws_api_gateway_method" "notify_post" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.notify.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "notify_post" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id              = aws_api_gateway_resource.notify.id
  http_method              = aws_api_gateway_method.notify_post.http_method
  integration_http_method  = "POST"
  type                      = "AWS_PROXY"
  uri                       = aws_lambda_function.notify_processor.invoke_arn
}

resource "aws_lambda_permission" "notify_processor" {
  statement_id  = "AllowAPIGatewayInvokeNotify"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.notify_processor.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

# ---- /notifications (GET) ----

resource "aws_api_gateway_resource" "notifications" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "notifications"
}

resource "aws_api_gateway_method" "notifications_get" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.notifications.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "notifications_get" {
  rest_api_id              = aws_api_gateway_rest_api.api.id
  resource_id              = aws_api_gateway_resource.notifications.id
  http_method              = aws_api_gateway_method.notifications_get.http_method
  integration_http_method  = "POST"
  type                     = "AWS_PROXY"
  uri                      = aws_lambda_function.notify_query.invoke_arn
}

resource "aws_lambda_permission" "notify_query" {
  statement_id  = "AllowAPIGatewayInvokeNotifications"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.notify_query.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

# ---- CORS (OPTIONS preflight on both resources) ----

module "cors_notify" {
  source      = "./modules/cors"
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.notify.id
}

module "cors_notifications" {
  source      = "./modules/cors"
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.notifications.id
}

# ---- Deployment ----

resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.notify.id,
      aws_api_gateway_method.notify_post.id,
      aws_api_gateway_integration.notify_post.id,
      aws_api_gateway_resource.notifications.id,
      aws_api_gateway_method.notifications_get.id,
      aws_api_gateway_integration.notifications_get.id,
      module.cors_notify.method_id,
      module.cors_notifications.method_id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.deployment.id
  rest_api_id   = aws_api_gateway_rest_api.api.id
  stage_name    = "prod"
}
