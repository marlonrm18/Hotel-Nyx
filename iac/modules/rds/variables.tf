variable "project" {
  description = "Nombre del proyecto, usado en tags y nombres de recursos"
  type        = string
}

variable "environment" {
  description = "Nombre del ambiente de despliegue"
  type        = string
}

variable "partition" {
  description = "Partición AWS (para el ARN de la managed policy de Enhanced Monitoring)"
  type        = string
}

variable "private_subnet_ids" {
  description = "IDs de las subnets privadas para el DB subnet group"
  type        = list(string)
}

variable "rds_sg_id" {
  description = "ID del Security Group de RDS"
  type        = string
}

variable "rds_kms_key_arn" {
  description = "ARN de la CMK para cifrar el storage y Performance Insights"
  type        = string
}

variable "rds_postgres_version" {
  description = "Version del motor PostgreSQL (major.minor, ej: 16.3)"
  type        = string
}

variable "rds_instance_class" {
  description = "Clase de instancia RDS (db.t4g.micro mínimo dev; Multi-AZ se mantiene)"
  type        = string
}

variable "rds_allocated_storage" {
  description = "Almacenamiento inicial en GB (gp3)"
  type        = number
}

variable "rds_max_allocated_storage" {
  description = "Limite maximo de autoscaling de almacenamiento en GB"
  type        = number
}

variable "rds_db_name" {
  description = "Nombre de la base de datos inicial"
  type        = string
}

variable "rds_master_username" {
  description = "Usuario maestro de la BD"
  type        = string
}

variable "rds_backup_retention_days" {
  description = "Dias de retencion de backups automaticos"
  type        = number
}

variable "rds_deletion_protection" {
  description = "Activar proteccion contra borrado accidental"
  type        = bool
}

variable "rds_skip_final_snapshot" {
  description = "Omitir snapshot final al destruir"
  type        = bool
}

variable "rds_performance_insights_retention" {
  description = "Dias de retencion de Performance Insights"
  type        = number
}
