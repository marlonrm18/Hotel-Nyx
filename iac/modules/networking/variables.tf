variable "project" {
  description = "Nombre del proyecto, usado en tags y nombres de recursos"
  type        = string
}

variable "environment" {
  description = "Nombre del ambiente de despliegue"
  type        = string
}

variable "vpc_cidr" {
  description = "Bloque CIDR de la VPC"
  type        = string
}

variable "availability_zones" {
  description = "Lista de AZs a usar dentro de la región principal"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDRs de las subnets públicas (uno por AZ, en el mismo orden que availability_zones)"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDRs de las subnets privadas (uno por AZ, en el mismo orden que availability_zones)"
  type        = list(string)
}

variable "single_nat_gateway" {
  description = "true → un solo NAT GW (ahorro en dev/test); false → uno por AZ (alta disponibilidad)"
  type        = bool
}
