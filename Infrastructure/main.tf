terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# DynamoDB Tables
resource "aws_dynamodb_table" "events" {
  name           = "Events"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "eventId"

  attribute {
    name = "eventId"
    type = "S"
  }

  tags = {
    Project = "EventTicketing"
  }
}

resource "aws_dynamodb_table" "registrations" {
  name           = "Registrations"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "registrationId"

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

  tags = {
    Project = "EventTicketing"
  }
}

# Outputs
output "api_url" {
  description = "API Gateway URL"
  value       = "Will be available after deployment"
}

output "dynamodb_tables" {
  description = "DynamoDB table names"
  value = {
    events        = aws_dynamodb_table.events.name
    registrations = aws_dynamodb_table.registrations.name
  }
}