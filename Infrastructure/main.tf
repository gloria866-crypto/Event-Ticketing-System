terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  default = "us-east-1"
}

# ─── DynamoDB ────────────────────────────────────────────────────────────────

resource "aws_dynamodb_table" "events" {
  name         = "Events"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "eventId"

  attribute {
    name = "eventId"
    type = "S"
  }

  tags = { Project = "EventTicketing" }
}

resource "aws_dynamodb_table" "registrations" {
  name         = "Registrations"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "registrationId"

  attribute {
    name = "registrationId"
    type = "S"
  }

  attribute {
    name = "email"
    type = "S"
  }

  global_secondary_index {
    name            = "EmailIndex"
    hash_key        = "email"
    projection_type = "ALL"
  }

  tags = { Project = "EventTicketing" }
}

# ─── IAM ─────────────────────────────────────────────────────────────────────

resource "aws_iam_role" "lambda_exec" {
  name = "event_ticketing_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_dynamodb" {
  name = "lambda_dynamodb_policy"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:Scan",
        "dynamodb:Query"
      ]
      Resource = [
        aws_dynamodb_table.events.arn,
        aws_dynamodb_table.registrations.arn,
        "${aws_dynamodb_table.registrations.arn}/index/EmailIndex"
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# ─── Lambda packaging ────────────────────────────────────────────────────────

data "archive_file" "events_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../Lambda"
  output_path = "${path.module}/zips/events.zip"
}

data "archive_file" "register_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../Lambda"
  output_path = "${path.module}/zips/register.zip"
}

data "archive_file" "registrations_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../Lambda"
  output_path = "${path.module}/zips/registrations.zip"
}

data "archive_file" "cancel_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../Lambda"
  output_path = "${path.module}/zips/cancel.zip"
}

# ─── Lambda functions ────────────────────────────────────────────────────────

locals {
  lambda_env = {
    EVENTS_TABLE        = aws_dynamodb_table.events.name
    REGISTRATIONS_TABLE = aws_dynamodb_table.registrations.name
  }
}

resource "aws_lambda_function" "events" {
  function_name    = "events-handler"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "events/handler.lambda_handler"
  runtime          = "python3.9"
  filename         = data.archive_file.events_zip.output_path
  source_code_hash = data.archive_file.events_zip.output_base64sha256
  timeout          = 30
  memory_size      = 128
  environment { variables = local.lambda_env }
}

resource "aws_lambda_function" "register" {
  function_name    = "register-handler"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "register/handler.lambda_handler"
  runtime          = "python3.9"
  filename         = data.archive_file.register_zip.output_path
  source_code_hash = data.archive_file.register_zip.output_base64sha256
  timeout          = 30
  memory_size      = 128
  environment { variables = local.lambda_env }
}

resource "aws_lambda_function" "registrations" {
  function_name    = "registrations-handler"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "registrations/handler.lambda_handler"
  runtime          = "python3.9"
  filename         = data.archive_file.registrations_zip.output_path
  source_code_hash = data.archive_file.registrations_zip.output_base64sha256
  timeout          = 30
  memory_size      = 128
  environment { variables = local.lambda_env }
}

resource "aws_lambda_function" "cancel" {
  function_name    = "cancel-handler"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "cancel/handler.lambda_handler"
  runtime          = "python3.9"
  filename         = data.archive_file.cancel_zip.output_path
  source_code_hash = data.archive_file.cancel_zip.output_base64sha256
  timeout          = 30
  memory_size      = 128
  environment { variables = local.lambda_env }
}

# ─── API Gateway ─────────────────────────────────────────────────────────────

resource "aws_apigatewayv2_api" "api" {
  name          = "event-ticketing-api"
  protocol_type = "HTTP"
  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "DELETE", "OPTIONS"]
    allow_headers = ["Content-Type"]
  }
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "events" {
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.events.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "register" {
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.register.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "registrations" {
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.registrations.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "cancel" {
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.cancel.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "get_events" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "GET /events"
  target    = "integrations/${aws_apigatewayv2_integration.events.id}"
}

resource "aws_apigatewayv2_route" "post_register" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "POST /register"
  target    = "integrations/${aws_apigatewayv2_integration.register.id}"
}

resource "aws_apigatewayv2_route" "get_registrations" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "GET /registrations/{email}"
  target    = "integrations/${aws_apigatewayv2_integration.registrations.id}"
}

resource "aws_apigatewayv2_route" "delete_registration" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "DELETE /registration/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.cancel.id}"
}

resource "aws_lambda_permission" "events" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.events.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "register" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.register.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "registrations" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.registrations.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "cancel" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cancel.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

# ─── CloudWatch Alarms ───────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  for_each = {
    events        = aws_lambda_function.events.function_name
    register      = aws_lambda_function.register.function_name
    registrations = aws_lambda_function.registrations.function_name
    cancel        = aws_lambda_function.cancel.function_name
  }

  alarm_name          = "${each.value}-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Error rate > 5 for ${each.value}"

  dimensions = { FunctionName = each.value }
}

# ─── Outputs ─────────────────────────────────────────────────────────────────

output "api_url" {
  description = "API Gateway base URL"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "dynamodb_tables" {
  value = {
    events        = aws_dynamodb_table.events.name
    registrations = aws_dynamodb_table.registrations.name
  }
}
