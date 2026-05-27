terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = var.region
  profile = var.aws_profile
}

# IAM Role for Lambda

resource "aws_iam_role" "lambda_execution_role" {
  name = "mlops-lambda-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# IAM Role for Step Functions

resource "aws_iam_role" "step_function_role" {
  name = "mlops-step-function-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = { Service = "states.amazonaws.com" }
      }
    ]
  })
}

resource "aws_iam_role_policy" "step_function_lambda_policy" {
  name = "mlops-step-function-lambda-policy"
  role = aws_iam_role.step_function_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["lambda:InvokeFunction"]
        Resource = [
          aws_lambda_function.validate.arn,
          aws_lambda_function.log_metrics.arn,
        ]
      }
    ]
  })
}

# Lambda Functions

resource "aws_lambda_function" "validate" {
  filename         = "${path.module}/lambda/validate.zip"
  function_name    = var.validate_function_name
  role             = aws_iam_role.lambda_execution_role.arn
  handler          = "validate.handler"
  runtime          = "python3.12"
  source_code_hash = filebase64sha256("${path.module}/lambda/validate.zip")
}

resource "aws_lambda_function" "log_metrics" {
  filename         = "${path.module}/lambda/log_metrics.zip"
  function_name    = var.log_metrics_function_name
  role             = aws_iam_role.lambda_execution_role.arn
  handler          = "log_metrics.handler"
  runtime          = "python3.12"
  source_code_hash = filebase64sha256("${path.module}/lambda/log_metrics.zip")
}

# Step Function State Machine

resource "aws_sfn_state_machine" "train_pipeline" {
  name     = var.state_machine_name
  role_arn = aws_iam_role.step_function_role.arn

  definition = jsonencode({
    Comment = "ML Training Pipeline: ValidateData -> LogMetrics"
    StartAt = "ValidateData"
    States = {
      ValidateData = {
        Type     = "Task"
        Resource = aws_lambda_function.validate.arn
        Next     = "LogMetrics"
      }
      LogMetrics = {
        Type     = "Task"
        Resource = aws_lambda_function.log_metrics.arn
        End      = true
      }
    }
  })
}

output "state_machine_arn" {
  description = "ARN of the Step Function state machine"
  value       = aws_sfn_state_machine.train_pipeline.arn
}
