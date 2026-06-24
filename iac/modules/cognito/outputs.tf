output "user_pool_id" {
  description = "ID del User Pool de Cognito"
  value       = aws_cognito_user_pool.main.id
}

output "user_pool_arn" {
  description = "ARN del User Pool (usado por API Gateway Cognito authorizer)"
  value       = aws_cognito_user_pool.main.arn
}

output "client_id" {
  description = "ID del app client de Cognito"
  value       = aws_cognito_user_pool_client.main.id
}

output "user_pool_domain" {
  description = "Dominio (prefijo) de la hosted UI de Cognito"
  value       = aws_cognito_user_pool_domain.main.domain
}
