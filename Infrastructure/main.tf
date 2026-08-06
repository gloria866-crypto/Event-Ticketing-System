terraform {
  backend "s3" {
    bucket       = "event-ticketing-terraform-state-812616070438"
    key          = "event-ticketing-system/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }

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


# ─── SNS ─────────────────────────────────────────────────────────────────────

resource "aws_sns_topic" "alarms" {
  name = "event-ticketing-alarms"
}

resource "aws_sns_topic_subscription" "alarm_email" {
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = "yaaappaih2@gmail.com"
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

  point_in_time_recovery { enabled = true }

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

  point_in_time_recovery { enabled = true }

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
  runtime          = "python3.13"
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
  runtime          = "python3.13"
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
  runtime          = "python3.13"
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
  runtime          = "python3.13"
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

  default_route_settings {
    throttling_burst_limit = 50
    throttling_rate_limit  = 100
  }
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

# Error rate > 5% per Lambda (Errors / Invocations)
resource "aws_cloudwatch_metric_alarm" "lambda_error_rate" {
  for_each = {
    events        = aws_lambda_function.events.function_name
    register      = aws_lambda_function.register.function_name
    registrations = aws_lambda_function.registrations.function_name
    cancel        = aws_lambda_function.cancel.function_name
  }

  alarm_name          = "${each.value}-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = 5
  alarm_description   = "Error rate > 5% for ${each.value}"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  metric_query {
    id          = "error_rate"
    expression  = "(errors / MAX([errors, invocations])) * 100"
    label       = "Error Rate %"
    return_data = true
  }

  metric_query {
    id = "errors"
    metric {
      metric_name = "Errors"
      namespace   = "AWS/Lambda"
      period      = 60
      stat        = "Sum"
      dimensions  = { FunctionName = each.value }
    }
  }

  metric_query {
    id = "invocations"
    metric {
      metric_name = "Invocations"
      namespace   = "AWS/Lambda"
      period      = 60
      stat        = "Sum"
      dimensions  = { FunctionName = each.value }
    }
  }
}

# Lambda duration alarm — p99 > 10 seconds
resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  for_each = {
    events        = aws_lambda_function.events.function_name
    register      = aws_lambda_function.register.function_name
    registrations = aws_lambda_function.registrations.function_name
    cancel        = aws_lambda_function.cancel.function_name
  }

  alarm_name          = "${each.value}-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 60
  extended_statistic  = "p99"
  threshold           = 10000
  alarm_description   = "p99 duration > 10s for ${each.value}"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = { FunctionName = each.value }
}

# API Gateway request count alarm — > 1000 requests/minute
resource "aws_cloudwatch_metric_alarm" "api_request_count" {
  alarm_name          = "api-high-request-count"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Count"
  namespace           = "AWS/ApiGateway"
  period              = 60
  statistic           = "Sum"
  threshold           = 1000
  alarm_description   = "API requests > 1000/min"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    ApiId = aws_apigatewayv2_api.api.id
  }
}

# API Gateway 5xx errors > 10/minute
resource "aws_cloudwatch_metric_alarm" "api_5xx_errors" {
  alarm_name          = "api-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = 60
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "API Gateway 5xx errors > 10/min"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    ApiId = aws_apigatewayv2_api.api.id
  }
}

# API Gateway 4xx errors > 50/minute (failed registrations / bad requests)
resource "aws_cloudwatch_metric_alarm" "api_4xx_errors" {
  alarm_name          = "api-4xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "4XXError"
  namespace           = "AWS/ApiGateway"
  period              = 60
  statistic           = "Sum"
  threshold           = 50
  alarm_description   = "API Gateway 4xx errors > 50/min"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    ApiId = aws_apigatewayv2_api.api.id
  }
}

# ─── CloudWatch Dashboard ────────────────────────────────────────────────────

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "EventTicketing"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "Lambda Invocations"
          view    = "timeSeries"
          region  = var.aws_region
          period  = 60
          stat    = "Sum"
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.events.function_name],
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.register.function_name],
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.registrations.function_name],
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.cancel.function_name]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "Lambda Errors"
          view    = "timeSeries"
          region  = var.aws_region
          period  = 60
          stat    = "Sum"
          metrics = [
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.events.function_name],
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.register.function_name],
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.registrations.function_name],
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.cancel.function_name]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "Lambda Duration (p99)"
          view    = "timeSeries"
          region  = var.aws_region
          period  = 60
          stat    = "p99"
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.events.function_name],
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.register.function_name],
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.registrations.function_name],
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.cancel.function_name]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "API Gateway — Requests, 4xx & 5xx"
          view    = "timeSeries"
          region  = var.aws_region
          period  = 60
          stat    = "Sum"
          metrics = [
            ["AWS/ApiGateway", "Count",    "ApiId", aws_apigatewayv2_api.api.id],
            ["AWS/ApiGateway", "4XXError", "ApiId", aws_apigatewayv2_api.api.id],
            ["AWS/ApiGateway", "5XXError", "ApiId", aws_apigatewayv2_api.api.id]
          ]
        }
      }
    ]
  })
}

# ─── Outputs ─────────────────────────────────────────────────────────────────

output "sns_topic_arn" {
  description = "SNS topic ARN for alarm notifications"
  value       = aws_sns_topic.alarms.arn
}

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

# ─── Static frontend hosting ────────────────────────────────────────────────

resource "aws_s3_bucket" "frontend" {
  bucket = "event-ticketing-frontend-812616070438"

  tags = { Project = "EventTicketing" }
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket                  = aws_s3_bucket.frontend.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_cloudfront_origin_access_control" "frontend" {
  name                              = "event-ticketing-frontend-oac"
  description                       = "CloudFront access to the Event Ticketing frontend bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "frontend" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  price_class         = "PriceClass_100"

  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "event-ticketing-frontend-s3"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "event-ticketing-frontend-s3"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = { Project = "EventTicketing" }
}

data "aws_iam_policy_document" "frontend_bucket" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.frontend.arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.frontend.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  policy = data.aws_iam_policy_document.frontend_bucket.json

  depends_on = [aws_s3_bucket_public_access_block.frontend]
}

locals {
  frontend_content_types = {
    "css"  = "text/css"
    "html" = "text/html"
    "js"   = "application/javascript"
  }
}

resource "aws_s3_object" "frontend_files" {
  for_each = fileset("${path.module}/../frontend", "**")

  bucket       = aws_s3_bucket.frontend.id
  key          = each.value
  source       = "${path.module}/../frontend/${each.value}"
  etag         = filemd5("${path.module}/../frontend/${each.value}")
  content_type = lookup(local.frontend_content_types, element(reverse(split(".", each.value)), 0), "application/octet-stream")

  depends_on = [aws_s3_bucket_ownership_controls.frontend]
}

resource "aws_s3_object" "frontend_config" {
  bucket       = aws_s3_bucket.frontend.id
  key          = "config.js"
  content      = "window.EVENTGLOVA_API_URL = ${jsonencode(aws_apigatewayv2_stage.default.invoke_url)};\n"
  content_type = "application/javascript"

  depends_on = [aws_s3_bucket_ownership_controls.frontend]
}

output "frontend_url" {
  description = "Public CloudFront URL for the Event Ticketing frontend"
  value       = "https://${aws_cloudfront_distribution.frontend.domain_name}"
}
