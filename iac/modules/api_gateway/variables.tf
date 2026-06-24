variable "project" {
  description = "Nombre del proyecto, usado en tags y nombres de recursos"
  type        = string
}

variable "environment" {
  description = "Nombre del ambiente de despliegue"
  type        = string
}

variable "aws_region" {
  description = "Región AWS principal (issuer del JWT)"
  type        = string
}

variable "domain_name" {
  description = "Dominio raíz (dominio custom api.<domain> y alias DNS)"
  type        = string
}

variable "ecs_logs_key_arn" {
  description = "ARN de la CMK para cifrar el log group de la API"
  type        = string
}

variable "ecs_log_retention_days" {
  description = "Días de retención del log group de la API"
  type        = number
}

variable "cognito_user_pool_id" {
  description = "ID del User Pool de Cognito (issuer del JWT authorizer)"
  type        = string
}

variable "cognito_client_id" {
  description = "ID del app client de Cognito (audience del JWT authorizer)"
  type        = string
}

variable "alb_dns_name" {
  description = "DNS name del ALB (backend de la integración HTTP_PROXY)"
  type        = string
}

variable "acm_certificate_arn" {
  description = "ARN del certificado ACM regional validado (dominio custom)"
  type        = string
}

variable "route53_zone_id" {
  description = "ID de la hosted zone donde se crea el alias api.<domain>"
  type        = string
}

variable "api_cors_allow_origins" {
  description = "Origenes permitidos en la politica CORS de la API"
  type        = list(string)
}

variable "api_throttling_burst_limit" {
  description = "Limite de rafaga de solicitudes en el stage"
  type        = number
}

variable "api_throttling_rate_limit" {
  description = "Limite de tasa de solicitudes por segundo en el stage"
  type        = number
}
