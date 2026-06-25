variable "aws_region" {
  description = "Región AWS donde viven el bucket de state y la tabla de locks"
  type        = string
  default     = "us-east-2"
}

variable "project" {
  description = "Nombre del proyecto, usado como prefijo de los recursos"
  type        = string
  default     = "hotel-nyx"
}

variable "name_suffix" {
  description = <<-EOT
    Sufijo que hace ÚNICO GLOBALMENTE el nombre del bucket S3 (los nombres de
    bucket son globales en todo AWS). Usa algo estable y propio de la cuenta,
    p. ej. el account id o un id corto aleatorio. Resultado:
    "<project>-tfstate-<name_suffix>".
  EOT
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,40}$", var.name_suffix))
    error_message = "name_suffix: solo minúsculas, números y guiones (3-40 chars)."
  }
}

variable "lock_table_name" {
  description = "Nombre de la tabla DynamoDB para el state locking (única por cuenta/región, no global)"
  type        = string
  default     = "hotel-nyx-tflocks"
}

variable "force_destroy_state_bucket" {
  description = "Si es true permite borrar el bucket aunque tenga objetos. Déjalo en false: el bucket de state NO debe borrarse a la ligera."
  type        = bool
  default     = false
}
