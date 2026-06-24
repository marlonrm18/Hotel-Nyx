output "bucket_name" {
  description = "Nombre del bucket S3 del frontend estatico"
  value       = aws_s3_bucket.frontend.id
}

output "bucket_arn" {
  description = "ARN del bucket S3 del frontend"
  value       = aws_s3_bucket.frontend.arn
}

output "distribution_id" {
  description = "ID de la distribucion CloudFront (para invalidaciones de cache)"
  value       = aws_cloudfront_distribution.main.id
}

output "distribution_arn" {
  description = "ARN de la distribucion CloudFront"
  value       = aws_cloudfront_distribution.main.arn
}

output "distribution_domain_name" {
  description = "Dominio CloudFront asignado por AWS"
  value       = aws_cloudfront_distribution.main.domain_name
}

output "distribution_hosted_zone_id" {
  description = "Hosted zone ID de CloudFront (Z2FDTNDATAQYW2)"
  value       = aws_cloudfront_distribution.main.hosted_zone_id
}

output "acm_certificate_arn" {
  description = "ARN del certificado ACM us-east-1 para CloudFront"
  value       = aws_acm_certificate_validation.cloudfront.certificate_arn
}
