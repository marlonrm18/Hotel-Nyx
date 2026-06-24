variable "project" {
  description = "Nombre del proyecto, usado en tags y nombres de recursos"
  type        = string
}

variable "environment" {
  description = "Nombre del ambiente de despliegue"
  type        = string
}

variable "domain_name" {
  description = "Dominio raíz del proyecto (nombre de la hosted zone)"
  type        = string
}
