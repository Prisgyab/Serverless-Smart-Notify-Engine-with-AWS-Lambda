variable "aws_region" {
  description = "AWS region to deploy resources"
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix used to name all resources"
  default     = "smart-notify"
}

variable "notification_email" {
  description = "Email address subscribed to the SNS topic (receives notification emails)"
  type        = string
}
