variable "project" {
  description = "Nombre del proyecto, usado en tags y nombres de recursos"
  type        = string
}

variable "environment" {
  description = "Nombre del ambiente de despliegue"
  type        = string
}

variable "aws_region" {
  description = "Región AWS principal (para construir ARNs)"
  type        = string
}

variable "account_id" {
  description = "ID de la cuenta AWS"
  type        = string
}

variable "partition" {
  description = "Partición AWS"
  type        = string
}

variable "domain_name" {
  description = "Dominio raíz (para restringir el identity SES en las policies)"
  type        = string
}

variable "rds_secret_arn" {
  description = "ARN del secret de RDS (acceso por ARN exacto)"
  type        = string
}

variable "mercadopago_secret_arn" {
  description = "ARN del secret de Mercado Pago (acceso por ARN exacto desde svc-pagos)"
  type        = string
}

variable "rds_kms_key_arn" {
  description = "ARN de la CMK con la que se descifran los secrets en runtime"
  type        = string
}
