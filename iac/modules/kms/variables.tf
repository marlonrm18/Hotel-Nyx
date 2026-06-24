variable "project" {
  description = "Nombre del proyecto, usado en tags y nombres de recursos"
  type        = string
}

variable "environment" {
  description = "Nombre del ambiente de despliegue"
  type        = string
}

variable "kms_deletion_window_days" {
  description = "Días de espera antes de destruir una KMS key (mínimo 7, máximo 30)"
  type        = number
}

variable "aws_region" {
  description = "Región AWS principal (para el key policy de CloudWatch Logs)"
  type        = string
}

variable "account_id" {
  description = "ID de la cuenta AWS (data.aws_caller_identity.current.account_id)"
  type        = string
}

variable "partition" {
  description = "Partición AWS (data.aws_partition.current.partition)"
  type        = string
}
