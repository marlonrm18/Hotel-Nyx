variable "project" {
  description = "Nombre del proyecto, usado en tags y nombres de recursos"
  type        = string
}

variable "environment" {
  description = "Nombre del ambiente de despliegue"
  type        = string
}

variable "secrets_recovery_window_days" {
  description = "Dias antes de destruir permanentemente un secret eliminado"
  type        = number
}

variable "rds_kms_key_arn" {
  description = "ARN de la CMK con la que se cifran ambos secrets"
  type        = string
}

variable "db_host" {
  description = "Hostname de RDS (address) para la credencial almacenada"
  type        = string
}

variable "db_port" {
  description = "Puerto de RDS"
  type        = number
}

variable "db_name" {
  description = "Nombre de la base de datos"
  type        = string
}

variable "db_username" {
  description = "Usuario maestro de la BD"
  type        = string
}

variable "db_password" {
  description = "Contraseña del usuario maestro (generada en el módulo rds)"
  type        = string
  sensitive   = true
}
