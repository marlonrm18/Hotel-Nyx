variable "project" {
  description = "Nombre del proyecto, usado en tags y nombres de recursos"
  type        = string
}

variable "environment" {
  description = "Nombre del ambiente de despliegue"
  type        = string
}

variable "aws_region" {
  description = "Región AWS principal (widgets del dashboard)"
  type        = string
}

variable "account_id" {
  description = "ID de la cuenta AWS (policies SNS)"
  type        = string
}

variable "partition" {
  description = "Partición AWS (root principal de la policy SNS)"
  type        = string
}

variable "alert_email" {
  description = "Correo que recibe las alertas de SNS"
  type        = string
}

variable "monitoring_key_id" {
  description = "Key ID de la CMK de monitoring (kms_master_key_id del topic)"
  type        = string
}

# ─── Dimensiones de recursos monitoreados ────────────────────────────────────

variable "alb_arn_suffix" {
  description = "Sufijo del ARN del ALB (dimensión LoadBalancer)"
  type        = string
}

variable "tg_reservas_arn_suffix" {
  description = "Sufijo del ARN del target group reservas"
  type        = string
}

variable "tg_pagos_arn_suffix" {
  description = "Sufijo del ARN del target group pagos"
  type        = string
}

variable "ecs_cluster_name" {
  description = "Nombre del cluster ECS (dimensión ClusterName)"
  type        = string
}

variable "ecs_service_reservas_name" {
  description = "Nombre del servicio ECS svc-reservas"
  type        = string
}

variable "ecs_service_pagos_name" {
  description = "Nombre del servicio ECS svc-pagos"
  type        = string
}

variable "rds_identifier" {
  description = "Identificador de la instancia RDS (dimensión DBInstanceIdentifier)"
  type        = string
}

variable "api_id" {
  description = "ID de la HTTP API (dimensión ApiId)"
  type        = string
}

# ─── Umbrales de alarmas ─────────────────────────────────────────────────────

variable "monitoring_alarm_5xx_threshold" {
  description = "Numero de errores 5xx por minuto que activa la alarma"
  type        = number
}

variable "monitoring_alarm_latency_threshold_ms" {
  description = "Latencia p99 en milisegundos que activa la alarma"
  type        = number
}

variable "monitoring_ecs_cpu_threshold" {
  description = "% de CPU/Memoria promedio en ECS que activa la alarma"
  type        = number
}

variable "monitoring_rds_cpu_threshold" {
  description = "% de CPU promedio en RDS que activa la alarma"
  type        = number
}

variable "monitoring_rds_free_storage_gb" {
  description = "GiB de almacenamiento libre en RDS bajo el cual se activa la alarma"
  type        = number
}

variable "monitoring_rds_connections_threshold" {
  description = "Numero maximo de conexiones activas a RDS antes de la alarma"
  type        = number
}
