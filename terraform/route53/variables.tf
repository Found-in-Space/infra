variable "aws_region" {
  description = "AWS provider region. Route 53 is global, but the AWS provider still requires a region."
  type        = string
  default     = "eu-west-1"
}

