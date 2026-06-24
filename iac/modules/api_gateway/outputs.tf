output "api_id" {
  description = "ID de la HTTP API"
  value       = aws_apigatewayv2_api.main.id
}

output "api_endpoint" {
  description = "Endpoint por defecto de la API (antes del dominio custom)"
  value       = aws_apigatewayv2_api.main.api_endpoint
}

output "domain_target_domain_name" {
  description = "DNS name del dominio custom API Gateway (alias Route 53)"
  value       = aws_apigatewayv2_domain_name.api.domain_name_configuration[0].target_domain_name
}

output "domain_hosted_zone_id" {
  description = "Hosted zone ID del dominio custom API Gateway"
  value       = aws_apigatewayv2_domain_name.api.domain_name_configuration[0].hosted_zone_id
}
