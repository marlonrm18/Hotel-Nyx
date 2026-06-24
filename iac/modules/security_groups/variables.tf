variable "project" {
  description = "Nombre del proyecto, usado en tags y nombres de recursos"
  type        = string
}

variable "environment" {
  description = "Nombre del ambiente de despliegue"
  type        = string
}

variable "vpc_id" {
  description = "ID de la VPC donde se crean los security groups"
  type        = string
}
