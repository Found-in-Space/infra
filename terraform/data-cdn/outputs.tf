output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name (use as the octree base URL)."
  value       = aws_cloudfront_distribution.octree.domain_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID (for cache invalidation)."
  value       = aws_cloudfront_distribution.octree.id
}

output "bucket_name" {
  description = "S3 bucket name."
  value       = local.bucket_id
}

output "octree_base_url" {
  description = "HTTPS base URL for octree data via CloudFront."
  value       = "https://${aws_cloudfront_distribution.octree.domain_name}"
}

output "data_cdn_domain_name" {
  description = "Stable public hostname for the Found in Space data CDN."
  value       = var.data_cdn_domain_name
}

output "data_cdn_base_url" {
  description = "Stable HTTPS base URL for Found in Space data assets."
  value       = "https://${var.data_cdn_domain_name}"
}

output "data_cdn_certificate_arn" {
  description = "ACM certificate ARN used by the CloudFront distribution."
  value       = aws_acm_certificate.data_cdn.arn
}
