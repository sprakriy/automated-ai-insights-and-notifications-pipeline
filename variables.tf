variable "aws_region" {
  description = "The AWS region to deploy resources in."
  type        = string
  default     = "us-east-1"
}
variable environment {
  description = "The environment to deploy resources in (e.g., dev, staging, prod)."
  type        = string
  default     = "dev"
}
variable notification_email {
  description = "The email address to receive notifications."
  type        = string
  default     = "shankar.prakriya@gmail.com"
}