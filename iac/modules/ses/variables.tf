variable "project" {
  description = "Nombre del proyecto, usado en tags y nombres de recursos"
  type        = string
}

variable "environment" {
  description = "Nombre del ambiente de despliegue"
  type        = string
}

variable "aws_region" {
  description = "Región AWS principal (endpoint SES y MX MAIL FROM)"
  type        = string
}

variable "domain_name" {
  description = "Dominio raíz a verificar en SES"
  type        = string
}

variable "alert_email" {
  description = "Correo de reportes DMARC (rua)"
  type        = string
}

variable "route53_zone_id" {
  description = "ID de la hosted zone donde se publican los registros SES"
  type        = string
}

variable "vpc_id" {
  description = "ID de la VPC para el interface endpoint de SES"
  type        = string
}

variable "private_subnet_ids" {
  description = "IDs de las subnets privadas donde se crean las ENIs del endpoint"
  type        = list(string)
}

variable "vpc_endpoints_sg_id" {
  description = "ID del Security Group de los VPC interface endpoints"
  type        = string
}
