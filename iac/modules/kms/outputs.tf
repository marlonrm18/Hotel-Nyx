output "rds_key_arn" {
  description = "ARN de la KMS key usada para cifrar RDS y su secret"
  value       = aws_kms_key.rds.arn
}

output "rds_key_id" {
  description = "Key ID de la CMK de RDS"
  value       = aws_kms_key.rds.key_id
}

output "ecr_key_arn" {
  description = "ARN de la KMS key usada para cifrar los repositorios ECR"
  value       = aws_kms_key.ecr.arn
}

output "ecs_logs_key_arn" {
  description = "ARN de la KMS key usada para cifrar los log groups de ECS y API Gateway"
  value       = aws_kms_key.ecs_logs.arn
}

output "frontend_key_arn" {
  description = "ARN de la KMS key usada para cifrar el bucket S3 del frontend"
  value       = aws_kms_key.frontend.arn
}

output "frontend_key_id" {
  description = "Key ID de la CMK del frontend (para aws_kms_key_policy en el módulo frontend)"
  value       = aws_kms_key.frontend.id
}

output "monitoring_key_id" {
  description = "Key ID de la CMK de monitoring (para kms_master_key_id del SNS topic)"
  value       = aws_kms_key.monitoring.key_id
}

output "monitoring_key_arn" {
  description = "ARN de la KMS key usada para cifrar el topic SNS de alertas"
  value       = aws_kms_key.monitoring.arn
}
