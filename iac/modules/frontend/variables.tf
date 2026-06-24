variable "project" {
  description = "Nombre del proyecto, usado en tags y nombres de recursos"
  type        = string
}

variable "environment" {
  description = "Nombre del ambiente de despliegue"
  type        = string
}

variable "domain_name" {
  description = "Dominio raíz (aliases CloudFront, cert y registros DNS)"
  type        = string
}

variable "account_id" {
  description = "ID de la cuenta AWS (nombre del bucket y key policy)"
  type        = string
}

variable "partition" {
  description = "Partición AWS (root principal de la key policy)"
  type        = string
}

variable "frontend_key_arn" {
  description = "ARN de la CMK del frontend (cifrado SSE-KMS del bucket)"
  type        = string
}

variable "frontend_key_id" {
  description = "Key ID de la CMK del frontend (target de aws_kms_key_policy)"
  type        = string
}

variable "cert_validation_record_fqdns" {
  description = "FQDNs de validación reutilizados para el cert us-east-1 de CloudFront"
  type        = list(string)
}

variable "route53_zone_id" {
  description = "ID de la hosted zone donde se crean los alias apex/www"
  type        = string
}

variable "s3_frontend_force_destroy" {
  description = "Permitir destruir el bucket S3 con objetos dentro (solo dev/test)"
  type        = bool
}

variable "cloudfront_price_class" {
  description = "Clase de precio de CloudFront"
  type        = string
}
