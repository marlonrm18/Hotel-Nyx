variable "project" {
  description = "Nombre del proyecto, usado en tags y nombres de recursos"
  type        = string
}

variable "environment" {
  description = "Nombre del ambiente de despliegue"
  type        = string
}

variable "ecr_image_retention_count" {
  description = "Número máximo de imágenes a retener por repositorio ECR"
  type        = number
}

variable "ecr_kms_key_arn" {
  description = "ARN de la CMK usada para cifrar los repositorios ECR"
  type        = string
}
