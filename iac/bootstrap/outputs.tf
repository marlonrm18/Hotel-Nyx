output "state_bucket_name" {
  description = "Nombre del bucket S3 del state. Úsalo como -backend-config=\"bucket=...\" en iac/."
  value       = aws_s3_bucket.state.id
}

output "lock_table_name" {
  description = "Nombre de la tabla DynamoDB de locks. Úsalo como -backend-config=\"dynamodb_table=...\" en iac/."
  value       = aws_dynamodb_table.locks.name
}

output "region" {
  description = "Región del backend remoto"
  value       = var.aws_region
}

# Snippet listo para copiar al archivo iac/backend.hcl (config parcial del backend).
output "backend_config_hcl" {
  description = "Contenido sugerido para iac/backend.hcl (backend-config parcial)"
  value       = <<-EOT
    bucket         = "${aws_s3_bucket.state.id}"
    dynamodb_table = "${aws_dynamodb_table.locks.name}"
  EOT
}
