output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name for accessing images"
  value       = aws_cloudfront_distribution.images.domain_name
}

output "api_gateway_url" {
  description = "API Gateway invoke URL"
  value       = aws_api_gateway_stage.prod.invoke_url
}
