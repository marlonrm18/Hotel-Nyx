output "db_endpoint" {
  description = "Endpoint de conexion a RDS (host:port)"
  value       = aws_db_instance.main.endpoint
}

output "db_address" {
  description = "Hostname del RDS (sin puerto)"
  value       = aws_db_instance.main.address
}

output "db_port" {
  description = "Puerto de RDS"
  value       = aws_db_instance.main.port
}

output "db_identifier" {
  description = "Identificador de la instancia RDS (para dimensiones de alarmas)"
  value       = aws_db_instance.main.identifier
}

output "db_password" {
  description = "Contraseña generada del usuario maestro (la guarda el módulo secrets)"
  value       = random_password.rds.result
  sensitive   = true
}
