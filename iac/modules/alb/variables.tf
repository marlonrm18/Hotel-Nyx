variable "project" {
  description = "Nombre del proyecto, usado en tags y nombres de recursos"
  type        = string
}

variable "environment" {
  description = "Nombre del ambiente de despliegue"
  type        = string
}

variable "domain_name" {
  description = "Dominio raíz (para el certificado ACM y su wildcard)"
  type        = string
}

variable "route53_zone_id" {
  description = "ID de la hosted zone donde se crean los registros de validación ACM"
  type        = string
}

variable "vpc_id" {
  description = "ID de la VPC (para los target groups)"
  type        = string
}

variable "public_subnet_ids" {
  description = "IDs de las subnets públicas donde se despliega el ALB"
  type        = list(string)
}

variable "alb_sg_id" {
  description = "ID del Security Group del ALB"
  type        = string
}

variable "alb_access_logs_bucket" {
  description = "Nombre del bucket S3 para access logs del ALB. Vacío = desactivado"
  type        = string
}

variable "alb_health_check_path" {
  description = "Path HTTP que los target groups usan para health checks"
  type        = string
}

variable "alb_reservas_path_patterns" {
  description = "Patrones de path que el ALB enruta hacia svc-reservas"
  type        = list(string)
}

variable "alb_pagos_path_patterns" {
  description = "Patrones de path que el ALB enruta hacia svc-pagos"
  type        = list(string)
}
