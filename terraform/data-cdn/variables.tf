variable "bucket_name" {
  description = "Name of the S3 bucket for octree data."
  type        = string
}

variable "create_bucket" {
  description = "Set to true to create the S3 bucket, false to use an existing one."
  type        = bool
  default     = false
}

variable "aws_region" {
  description = "AWS region for the S3 bucket."
  type        = string
  default     = "eu-central-1"
}

variable "cloudfront_price_class" {
  description = "CloudFront price class. PriceClass_100 = US/EU, PriceClass_200 adds Asia, PriceClass_All = global."
  type        = string
  default     = "PriceClass_100"
}

variable "cloudfront_comment" {
  description = "Comment / description for the CloudFront distribution."
  type        = string
  default     = "Found in Space octree data CDN"
}

variable "route53_zone_name" {
  description = "Public Route 53 hosted zone name for Found in Space."
  type        = string
  default     = "foundin.space"
}

variable "data_cdn_domain_name" {
  description = "Stable public hostname for the Found in Space data CDN."
  type        = string
  default     = "data.foundin.space"
}
