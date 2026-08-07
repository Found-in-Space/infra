terraform {
  required_version = ">= 1.5"

  required_providers {
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }

    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

data "aws_route53_zone" "foundin_space" {
  name         = var.route53_zone_name
  private_zone = false
}

# ---------------------------------------------------------------------------
# S3 bucket — create or reference existing
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "octree" {
  count  = var.create_bucket ? 1 : 0
  bucket = var.bucket_name
}

data "aws_s3_bucket" "existing" {
  count  = var.create_bucket ? 0 : 1
  bucket = var.bucket_name
}

locals {
  bucket_id                       = var.create_bucket ? aws_s3_bucket.octree[0].id : data.aws_s3_bucket.existing[0].id
  bucket_arn                      = var.create_bucket ? aws_s3_bucket.octree[0].arn : data.aws_s3_bucket.existing[0].arn
  bucket_regional_domain          = var.create_bucket ? aws_s3_bucket.octree[0].bucket_regional_domain_name : data.aws_s3_bucket.existing[0].bucket_regional_domain_name
  location_api_function_name      = "found-in-space-location-api-v1"
  location_api_origin_domain_name = trimsuffix(trimprefix(aws_lambda_function_url.location_api.function_url, "https://"), "/")
}

# Block public access on managed buckets (existing buckets keep their config).
resource "aws_s3_bucket_public_access_block" "octree" {
  count  = var.create_bucket ? 1 : 0
  bucket = aws_s3_bucket.octree[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CORS — needed so the browser can send Range headers cross-origin.
resource "aws_s3_bucket_cors_configuration" "octree" {
  count  = var.create_bucket ? 1 : 0
  bucket = aws_s3_bucket.octree[0].id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]
    expose_headers  = ["Content-Range", "Content-Length", "ETag"]
    max_age_seconds = 86400
  }
}

# ---------------------------------------------------------------------------
# CloudFront Origin Access Control
# ---------------------------------------------------------------------------

resource "aws_cloudfront_origin_access_control" "octree" {
  name                              = "${var.bucket_name}-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# ---------------------------------------------------------------------------
# S3 bucket policy — allow CloudFront OAC to read objects
# ---------------------------------------------------------------------------

resource "aws_s3_bucket_policy" "cloudfront_read" {
  bucket = local.bucket_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontServicePrincipalReadOnly"
        Effect    = "Allow"
        Principal = { Service = "cloudfront.amazonaws.com" }
        Action    = "s3:GetObject"
        Resource  = "${local.bucket_arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.octree.arn
          }
        }
      },
    ]
  })
}

# ---------------------------------------------------------------------------
# CloudFront cache policy — include Range header in cache key
# ---------------------------------------------------------------------------

resource "aws_cloudfront_cache_policy" "range_aware" {
  name        = "${var.bucket_name}-range-aware"
  min_ttl     = 86400
  default_ttl = 604800
  max_ttl     = 31536000
  comment     = "Cache octree range requests — Range header in cache key."

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = "none"
    }
    headers_config {
      header_behavior = "whitelist"
      headers {
        items = ["Range"]
      }
    }
    enable_accept_encoding_brotli = false
    enable_accept_encoding_gzip   = false
  }
}

# ---------------------------------------------------------------------------
# CloudFront response headers policy — CORS for browser range requests
# ---------------------------------------------------------------------------

resource "aws_cloudfront_response_headers_policy" "cors" {
  name    = "${var.bucket_name}-cors"
  comment = "CORS headers for octree range requests."

  cors_config {
    access_control_allow_credentials = false

    access_control_allow_headers {
      items = ["Range"]
    }

    access_control_allow_methods {
      items = ["GET", "HEAD"]
    }

    access_control_allow_origins {
      items = ["*"]
    }

    access_control_expose_headers {
      items = ["Content-Range", "Content-Length", "ETag", "Accept-Ranges"]
    }

    access_control_max_age_sec = 86400
    origin_override            = true
  }
}

# ---------------------------------------------------------------------------
# Edge time API
# ---------------------------------------------------------------------------

resource "aws_cloudfront_cache_policy" "time_api" {
  name        = "${var.bucket_name}-time-api-v1"
  min_ttl     = 0
  default_ttl = 0
  max_ttl     = 0
  comment     = "Disable caching for the edge-generated time API response."

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = "none"
    }
    headers_config {
      header_behavior = "none"
    }
    enable_accept_encoding_brotli = false
    enable_accept_encoding_gzip   = false
  }
}

resource "aws_cloudfront_function" "time_api" {
  name    = "found-in-space-time-api-v1"
  runtime = "cloudfront-js-2.0"
  comment = "Return the CloudFront edge invocation time at /api/v1/time."
  publish = true
  code    = file("${path.module}/functions/time-api-v1.js")
}

# ---------------------------------------------------------------------------
# Approximate viewer location API
# ---------------------------------------------------------------------------

data "archive_file" "location_api" {
  type        = "zip"
  source_file = "${path.module}/functions/location-api-v1.mjs"
  output_path = "${path.module}/.terraform/location-api-v1.zip"
}

data "aws_iam_policy_document" "location_api_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "location_api" {
  name               = local.location_api_function_name
  assume_role_policy = data.aws_iam_policy_document.location_api_assume_role.json
}

resource "aws_cloudwatch_log_group" "location_api" {
  name              = "/aws/lambda/${local.location_api_function_name}"
  retention_in_days = 14
}

data "aws_iam_policy_document" "location_api_logs" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["${aws_cloudwatch_log_group.location_api.arn}:*"]
  }
}

resource "aws_iam_role_policy" "location_api_logs" {
  name   = "write-function-logs"
  role   = aws_iam_role.location_api.id
  policy = data.aws_iam_policy_document.location_api_logs.json
}

resource "aws_lambda_function" "location_api" {
  function_name = local.location_api_function_name
  description   = "Return CloudFront's approximate viewer location without exposing the viewer IP."
  role          = aws_iam_role.location_api.arn
  handler       = "location-api-v1.handler"
  runtime       = "nodejs22.x"
  architectures = ["arm64"]
  memory_size   = 128
  timeout       = 3

  filename         = data.archive_file.location_api.output_path
  source_code_hash = data.archive_file.location_api.output_base64sha256

  depends_on = [
    aws_cloudwatch_log_group.location_api,
    aws_iam_role_policy.location_api_logs,
  ]
}

resource "aws_lambda_function_url" "location_api" {
  function_name      = aws_lambda_function.location_api.function_name
  authorization_type = "AWS_IAM"
}

resource "aws_cloudfront_origin_access_control" "location_api" {
  name                              = "${var.bucket_name}-location-api-v1-oac"
  description                       = "Sign requests from the data CDN to the private location API."
  origin_access_control_origin_type = "lambda"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_origin_request_policy" "location_api" {
  name    = "${var.bucket_name}-location-api-v1"
  comment = "Forward only CloudFront's non-IP viewer location headers."

  cookies_config {
    cookie_behavior = "none"
  }

  query_strings_config {
    query_string_behavior = "none"
  }

  headers_config {
    header_behavior = "whitelist"

    headers {
      items = [
        "CloudFront-Viewer-City",
        "CloudFront-Viewer-Country",
        "CloudFront-Viewer-Country-Name",
        "CloudFront-Viewer-Country-Region-Name",
        "CloudFront-Viewer-Latitude",
        "CloudFront-Viewer-Longitude",
        "CloudFront-Viewer-Postal-Code",
        "CloudFront-Viewer-Time-Zone",
      ]
    }
  }
}

resource "aws_cloudfront_response_headers_policy" "location_api" {
  name    = "${var.bucket_name}-location-api-v1"
  comment = "CORS, no-store, and browser security headers for the location API."

  cors_config {
    access_control_allow_credentials = false

    access_control_allow_headers {
      items = ["*"]
    }

    access_control_allow_methods {
      items = ["GET", "HEAD", "OPTIONS"]
    }

    access_control_allow_origins {
      items = ["*"]
    }

    access_control_max_age_sec = 86400
    origin_override            = true
  }

  custom_headers_config {
    items {
      header   = "Cache-Control"
      override = true
      value    = "no-store"
    }
  }

  security_headers_config {
    content_type_options {
      override = true
    }

    referrer_policy {
      override        = true
      referrer_policy = "no-referrer"
    }
  }
}

# ---------------------------------------------------------------------------
# Custom domain certificate and DNS validation
# ---------------------------------------------------------------------------

resource "aws_acm_certificate" "data_cdn" {
  provider = aws.us_east_1

  domain_name       = var.data_cdn_domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "data_cdn_certificate_validation" {
  for_each = {
    for option in aws_acm_certificate.data_cdn.domain_validation_options : option.domain_name => {
      name   = option.resource_record_name
      record = option.resource_record_value
      type   = option.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 300
  type            = each.value.type
  zone_id         = data.aws_route53_zone.foundin_space.zone_id
}

resource "aws_acm_certificate_validation" "data_cdn" {
  provider = aws.us_east_1

  certificate_arn         = aws_acm_certificate.data_cdn.arn
  validation_record_fqdns = [for record in aws_route53_record.data_cdn_certificate_validation : record.fqdn]
}

# ---------------------------------------------------------------------------
# CloudFront distribution
# ---------------------------------------------------------------------------

resource "aws_cloudfront_distribution" "octree" {
  comment             = var.cloudfront_comment
  enabled             = true
  is_ipv6_enabled     = true
  http_version        = "http2and3"
  price_class         = var.cloudfront_price_class
  wait_for_deployment = false
  aliases             = [var.data_cdn_domain_name]

  origin {
    domain_name              = local.bucket_regional_domain
    origin_id                = "s3-octree"
    origin_access_control_id = aws_cloudfront_origin_access_control.octree.id
  }

  origin {
    domain_name              = local.location_api_origin_domain_name
    origin_id                = "location-api-v1"
    origin_access_control_id = aws_cloudfront_origin_access_control.location_api.id

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id           = "s3-octree"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    cache_policy_id            = aws_cloudfront_cache_policy.range_aware.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.cors.id
    compress                   = false
  }

  ordered_cache_behavior {
    path_pattern           = "/api/v1/time"
    target_origin_id       = "s3-octree"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id        = aws_cloudfront_cache_policy.time_api.id
    compress               = false

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.time_api.arn
    }
  }

  ordered_cache_behavior {
    path_pattern               = "/api/v1/location"
    target_origin_id           = "location-api-v1"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    cache_policy_id            = aws_cloudfront_cache_policy.time_api.id
    origin_request_policy_id   = aws_cloudfront_origin_request_policy.location_api.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.location_api.id
    compress                   = false
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.data_cdn.certificate_arn
    minimum_protocol_version = "TLSv1.2_2021"
    ssl_support_method       = "sni-only"
  }
}

resource "aws_lambda_permission" "location_api_url_from_cloudfront" {
  statement_id           = "AllowCloudFrontFunctionUrl"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.location_api.function_name
  principal              = "cloudfront.amazonaws.com"
  source_arn             = aws_cloudfront_distribution.octree.arn
  function_url_auth_type = "AWS_IAM"
}

resource "aws_lambda_permission" "location_api_from_cloudfront" {
  statement_id  = "AllowCloudFrontInvokeFunction"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.location_api.function_name
  principal     = "cloudfront.amazonaws.com"
  source_arn    = aws_cloudfront_distribution.octree.arn
}

resource "aws_route53_record" "data_cdn_alias_a" {
  zone_id = data.aws_route53_zone.foundin_space.zone_id
  name    = var.data_cdn_domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.octree.domain_name
    zone_id                = aws_cloudfront_distribution.octree.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "data_cdn_alias_aaaa" {
  zone_id = data.aws_route53_zone.foundin_space.zone_id
  name    = var.data_cdn_domain_name
  type    = "AAAA"

  alias {
    name                   = aws_cloudfront_distribution.octree.domain_name
    zone_id                = aws_cloudfront_distribution.octree.hosted_zone_id
    evaluate_target_health = false
  }
}
