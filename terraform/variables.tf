variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS CLI profile"
  type        = string
  default     = "devops"
}

variable "validate_function_name" {
  description = "Name of the validate Lambda function"
  type        = string
  default     = "mlops-validate"
}

variable "log_metrics_function_name" {
  description = "Name of the log_metrics Lambda function"
  type        = string
  default     = "mlops-log-metrics"
}

variable "state_machine_name" {
  description = "Name of the Step Function state machine"
  type        = string
  default     = "mlops-train-pipeline"
}
