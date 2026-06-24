output "rds_secret_arn" {
  description = "ARN del Secrets Manager secret con credenciales de RDS"
  value       = aws_secretsmanager_secret.rds.arn
}

output "mercadopago_secret_arn" {
  description = "ARN del secret de Mercado Pago (cargar el valor real por CLI)"
  value       = aws_secretsmanager_secret.mercadopago.arn
}
