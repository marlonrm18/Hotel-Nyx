variable "project" {
  description = "Nombre del proyecto, usado en tags y nombres de recursos"
  type        = string
}

variable "environment" {
  description = "Nombre del ambiente de despliegue"
  type        = string
}

variable "aws_region" {
  description = "Región AWS principal (para awslogs-region)"
  type        = string
}

variable "domain_name" {
  description = "Dominio raíz (variables de entorno de los contenedores)"
  type        = string
}

# ─── Dependencias de otros módulos ───────────────────────────────────────────

variable "ecs_logs_key_arn" {
  description = "ARN de la CMK para cifrar los log groups"
  type        = string
}

variable "svc_reservas_repository_url" {
  description = "URL del repositorio ECR de svc-reservas"
  type        = string
}

variable "svc_pagos_repository_url" {
  description = "URL del repositorio ECR de svc-pagos"
  type        = string
}

variable "rds_secret_arn" {
  description = "ARN del secret de RDS (env var DB_SECRET_ARN)"
  type        = string
}

variable "mercadopago_secret_arn" {
  description = "ARN del secret de Mercado Pago (env var MP_SECRET_ARN)"
  type        = string
}

variable "ecs_execution_role_arn" {
  description = "ARN del task execution role compartido"
  type        = string
}

variable "svc_reservas_task_role_arn" {
  description = "ARN del task role de svc-reservas"
  type        = string
}

variable "svc_pagos_task_role_arn" {
  description = "ARN del task role de svc-pagos"
  type        = string
}

variable "private_subnet_ids" {
  description = "IDs de las subnets privadas donde corren las tareas"
  type        = list(string)
}

variable "ecs_sg_id" {
  description = "ID del Security Group de las tareas ECS"
  type        = string
}

variable "tg_reservas_arn" {
  description = "ARN del target group de svc-reservas"
  type        = string
}

variable "tg_pagos_arn" {
  description = "ARN del target group de svc-pagos"
  type        = string
}

variable "alb_arn_suffix" {
  description = "Sufijo del ARN del ALB (resource_label de autoscaling por requests)"
  type        = string
}

variable "tg_reservas_arn_suffix" {
  description = "Sufijo del ARN del target group reservas (resource_label autoscaling)"
  type        = string
}

variable "tg_pagos_arn_suffix" {
  description = "Sufijo del ARN del target group pagos (resource_label autoscaling)"
  type        = string
}

# ─── Configuración de servicio / tamaño ──────────────────────────────────────

variable "mp_notification_url" {
  description = "URL publica del webhook de Mercado Pago (PLACEHOLDER hasta el apply)"
  type        = string
}

variable "ecs_reservas_image_tag" {
  description = "Tag de imagen Docker para svc-reservas"
  type        = string
}

variable "ecs_pagos_image_tag" {
  description = "Tag de imagen Docker para svc-pagos"
  type        = string
}

variable "ecs_reservas_cpu" {
  description = "Unidades de CPU de la tarea svc-reservas"
  type        = number
}

variable "ecs_reservas_memory" {
  description = "Memoria (MiB) de la tarea svc-reservas"
  type        = number
}

variable "ecs_pagos_cpu" {
  description = "Unidades de CPU de la tarea svc-pagos"
  type        = number
}

variable "ecs_pagos_memory" {
  description = "Memoria (MiB) de la tarea svc-pagos"
  type        = number
}

variable "ecs_reservas_min_capacity" {
  description = "Número mínimo de tareas Fargate para svc-reservas"
  type        = number
}

variable "ecs_reservas_max_capacity" {
  description = "Número máximo de tareas Fargate para svc-reservas"
  type        = number
}

variable "ecs_pagos_min_capacity" {
  description = "Número mínimo de tareas Fargate para svc-pagos"
  type        = number
}

variable "ecs_pagos_max_capacity" {
  description = "Número máximo de tareas Fargate para svc-pagos"
  type        = number
}

variable "ecs_cpu_scale_target" {
  description = "% de CPU promedio que dispara el scale-out"
  type        = number
}

variable "ecs_alb_requests_per_target" {
  description = "Solicitudes ALB por tarea que disparan el scale-out"
  type        = number
}

variable "ecs_enable_execute_command" {
  description = "Habilitar ECS Exec para depuración interactiva"
  type        = bool
}

variable "ecs_log_retention_days" {
  description = "Días de retención de logs de contenedores en CloudWatch"
  type        = number
}
