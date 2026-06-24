# ─── Globales ────────────────────────────────────────────────────────────────

variable "aws_region" {
  description = "Región AWS principal (us-east-2 Ohio)"
  type        = string
  default     = "us-east-2"
}

variable "environment" {
  description = "Nombre del ambiente de despliegue"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "El ambiente debe ser dev, staging o prod."
  }
}

variable "project" {
  description = "Nombre del proyecto, usado en tags y nombres de recursos"
  type        = string
  default     = "hotel-nyx"
}

variable "domain_name" {
  description = "Dominio raíz del proyecto (sin www ni api)"
  type        = string
  default     = "hotelnyx.com"
}

variable "availability_zones" {
  description = "Lista de AZs a usar dentro de la región principal"
  type        = list(string)
  default     = ["us-east-2a", "us-east-2b"]
}

variable "alert_email" {
  description = "Correo que recibirá las alertas de SNS (monitoring)"
  type        = string
  sensitive   = true
}

# ─── VPC ─────────────────────────────────────────────────────────────────────

variable "vpc_cidr" {
  description = "Bloque CIDR de la VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr debe ser un bloque CIDR válido."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDRs de las subnets públicas (uno por AZ, en el mismo orden que availability_zones)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDRs de las subnets privadas (uno por AZ, en el mismo orden que availability_zones)"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "single_nat_gateway" {
  description = "true → un solo NAT GW (ahorro en dev/test); false → uno por AZ (alta disponibilidad). La redundancia por AZ es el atributo prioritario en staging/prod."
  type        = bool
  default     = false
}

# ─── KMS (compartido entre servicios) ────────────────────────────────────────

variable "kms_deletion_window_days" {
  description = "Días de espera antes de destruir una KMS key (mínimo 7, máximo 30)"
  type        = number
  default     = 7

  validation {
    condition     = var.kms_deletion_window_days >= 7 && var.kms_deletion_window_days <= 30
    error_message = "kms_deletion_window_days debe estar entre 7 y 30."
  }
}

# ─── ECR ─────────────────────────────────────────────────────────────────────

variable "ecr_image_retention_count" {
  description = "Número máximo de imágenes a retener por repositorio ECR"
  type        = number
  default     = 10

  validation {
    condition     = var.ecr_image_retention_count >= 1
    error_message = "ecr_image_retention_count debe ser al menos 1."
  }
}

# ─── ALB ─────────────────────────────────────────────────────────────────────

variable "alb_access_logs_bucket" {
  description = "Nombre del bucket S3 para access logs del ALB. Vacío = desactivado"
  type        = string
  default     = ""
}

variable "alb_health_check_path" {
  description = "Path HTTP que los target groups usan para health checks"
  type        = string
  default     = "/health"
}

variable "alb_reservas_path_patterns" {
  description = "Patrones de path que el ALB enruta hacia svc-reservas"
  type        = list(string)
  default     = ["/api/reservas", "/api/reservas/*"]
}

variable "alb_pagos_path_patterns" {
  description = "Patrones de path que el ALB enruta hacia svc-pagos"
  type        = list(string)
  default     = ["/api/pagos", "/api/pagos/*"]
}

# ─── ECS ─────────────────────────────────────────────────────────────────────

variable "mp_notification_url" {
  description = "URL publica del webhook de Mercado Pago (https://api.<dominio>/api/pagos/webhook). PLACEHOLDER: se rellena tras el apply, cuando exista el dominio del API Gateway. Vacio = svc-pagos no envia notification_url a MP."
  type        = string
  default     = ""
}

variable "ecs_reservas_image_tag" {
  description = "Tag de imagen Docker para svc-reservas"
  type        = string
  default     = "latest"
}

variable "ecs_pagos_image_tag" {
  description = "Tag de imagen Docker para svc-pagos"
  type        = string
  default     = "latest"
}

# Tamaño de tareas Fargate expuesto como variable. Defaults = el mínimo ya
# definido (0.25 vCPU / 512 MB para reservas). Mantener ≥ 2 tareas por servicio
# (ecs_*_min_capacity) repartidas en 2 AZs: solo se ajusta el TAMAÑO, no la
# redundancia.
variable "ecs_reservas_cpu" {
  description = "Unidades de CPU de la tarea svc-reservas (256 = 0.25 vCPU)"
  type        = number
  default     = 256
}

variable "ecs_reservas_memory" {
  description = "Memoria (MiB) de la tarea svc-reservas"
  type        = number
  default     = 512
}

variable "ecs_pagos_cpu" {
  description = "Unidades de CPU de la tarea svc-pagos (512 = 0.5 vCPU)"
  type        = number
  default     = 512
}

variable "ecs_pagos_memory" {
  description = "Memoria (MiB) de la tarea svc-pagos"
  type        = number
  default     = 1024
}

variable "ecs_reservas_min_capacity" {
  description = "Número mínimo de tareas Fargate para svc-reservas (≥ 2 para HA en 2 AZs)"
  type        = number
  default     = 2
}

variable "ecs_reservas_max_capacity" {
  description = "Número máximo de tareas Fargate para svc-reservas"
  type        = number
  default     = 6
}

variable "ecs_pagos_min_capacity" {
  description = "Número mínimo de tareas Fargate para svc-pagos (≥ 2 para HA en 2 AZs)"
  type        = number
  default     = 2
}

variable "ecs_pagos_max_capacity" {
  description = "Número máximo de tareas Fargate para svc-pagos"
  type        = number
  default     = 4
}

variable "ecs_cpu_scale_target" {
  description = "% de CPU promedio que dispara el scale-out (Target Tracking)"
  type        = number
  default     = 70
}

variable "ecs_alb_requests_per_target" {
  description = "Solicitudes ALB por tarea que disparan el scale-out"
  type        = number
  default     = 1000
}

variable "ecs_enable_execute_command" {
  description = "Habilitar ECS Exec para depuración interactiva (desactivar en prod)"
  type        = bool
  default     = false
}

variable "ecs_log_retention_days" {
  description = "Días de retención de logs de contenedores en CloudWatch"
  type        = number
  default     = 30
}

# ─── RDS ─────────────────────────────────────────────────────────────────────

variable "rds_postgres_version" {
  description = "Version del motor PostgreSQL (major.minor). 16.3/16.4 ya no son orderable en us-east-2; mínima 16.x disponible = 16.9."
  type        = string
  default     = "16.9"
}

variable "rds_instance_class" {
  description = "Clase de instancia RDS. Tamaño mínimo razonable para dev (db.t4g.micro); subir a db.r6g.large u otra Graviton mayor en prod. Multi-AZ se mantiene independientemente del tamaño."
  type        = string
  default     = "db.t4g.micro"
}

variable "rds_allocated_storage" {
  description = "Almacenamiento inicial en GB (gp3)"
  type        = number
  default     = 20
}

variable "rds_max_allocated_storage" {
  description = "Limite maximo de autoscaling de almacenamiento en GB"
  type        = number
  default     = 100
}

variable "rds_db_name" {
  description = "Nombre de la base de datos inicial"
  type        = string
  default     = "hotelnyx"
}

variable "rds_master_username" {
  description = "Usuario maestro de la BD (no usar 'admin' ni 'postgres', palabras reservadas)"
  type        = string
  default     = "hotelnyx_admin"
}

variable "rds_backup_retention_days" {
  description = "Dias de retencion de backups automaticos (min 1 para Multi-AZ)"
  type        = number
  default     = 7

  validation {
    condition     = var.rds_backup_retention_days >= 1 && var.rds_backup_retention_days <= 35
    error_message = "rds_backup_retention_days debe estar entre 1 y 35."
  }
}

variable "rds_deletion_protection" {
  description = "Activar proteccion contra borrado accidental (true en prod)"
  type        = bool
  default     = false
}

variable "rds_skip_final_snapshot" {
  description = "Omitir snapshot final al destruir (true en dev para agilizar, false en prod)"
  type        = bool
  default     = true
}

variable "rds_performance_insights_retention" {
  description = "Dias de retencion de Performance Insights (7 = tier gratuito, 731 = pagado)"
  type        = number
  default     = 7
}

variable "secrets_recovery_window_days" {
  description = "Dias antes de destruir permanentemente un secret eliminado de Secrets Manager"
  type        = number
  default     = 7

  validation {
    condition     = var.secrets_recovery_window_days >= 7 && var.secrets_recovery_window_days <= 30
    error_message = "secrets_recovery_window_days debe estar entre 7 y 30."
  }
}

# ─── Cognito ──────────────────────────────────────────────────────────────────

variable "cognito_password_min_length" {
  description = "Longitud minima de la contrasena de usuarios Cognito"
  type        = number
  default     = 12
}

variable "cognito_mfa_configuration" {
  description = "Configuracion de MFA: OFF | OPTIONAL | ON"
  type        = string
  default     = "OFF"

  validation {
    condition     = contains(["OFF", "OPTIONAL", "ON"], var.cognito_mfa_configuration)
    error_message = "cognito_mfa_configuration debe ser OFF, OPTIONAL u ON."
  }
}

variable "cognito_advanced_security_mode" {
  description = "Modo de seguridad avanzada de Cognito: OFF | AUDIT | ENFORCED (AUDIT/ENFORCED tienen costo adicional)"
  type        = string
  default     = "OFF"

  validation {
    condition     = contains(["OFF", "AUDIT", "ENFORCED"], var.cognito_advanced_security_mode)
    error_message = "cognito_advanced_security_mode debe ser OFF, AUDIT o ENFORCED."
  }
}

variable "cognito_callback_urls" {
  description = "URLs de callback OAuth2 permitidas en el app client"
  type        = list(string)
  default     = ["https://hotelnyx.com/callback", "https://www.hotelnyx.com/callback"]
}

variable "cognito_logout_urls" {
  description = "URLs de logout permitidas en el app client"
  type        = list(string)
  default     = ["https://hotelnyx.com", "https://www.hotelnyx.com"]
}

# ─── API Gateway ─────────────────────────────────────────────────────────────

variable "api_cors_allow_origins" {
  description = "Origenes permitidos en la politica CORS de la API"
  type        = list(string)
  default     = ["https://hotelnyx.com", "https://www.hotelnyx.com"]
}

variable "api_throttling_burst_limit" {
  description = "Limite de rafaga de solicitudes en el stage de API Gateway"
  type        = number
  default     = 100
}

variable "api_throttling_rate_limit" {
  description = "Limite de tasa de solicitudes por segundo en el stage de API Gateway"
  type        = number
  default     = 50
}

# ─── Frontend / CloudFront ────────────────────────────────────────────────────

variable "cloudfront_price_class" {
  description = "Clase de precio de CloudFront (PriceClass_100 = NA+EU; PriceClass_All = global)"
  type        = string
  default     = "PriceClass_100"

  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.cloudfront_price_class)
    error_message = "cloudfront_price_class debe ser PriceClass_100, PriceClass_200 o PriceClass_All."
  }
}

variable "s3_frontend_force_destroy" {
  description = "Permitir destruir el bucket S3 del frontend con objetos dentro (solo dev/test)"
  type        = bool
  default     = false
}

# ─── Monitoring ───────────────────────────────────────────────────────────────

variable "monitoring_alarm_5xx_threshold" {
  description = "Numero de errores 5xx por minuto que activa la alarma (ALB y API GW)"
  type        = number
  default     = 10
}

variable "monitoring_alarm_latency_threshold_ms" {
  description = "Latencia p99 en milisegundos que activa la alarma (ALB convierte a segundos internamente)"
  type        = number
  default     = 2000
}

variable "monitoring_ecs_cpu_threshold" {
  description = "% de CPU/Memoria promedio en ECS que activa la alarma"
  type        = number
  default     = 85
}

variable "monitoring_rds_cpu_threshold" {
  description = "% de CPU promedio en RDS que activa la alarma"
  type        = number
  default     = 80
}

variable "monitoring_rds_free_storage_gb" {
  description = "GiB de almacenamiento libre en RDS por debajo del cual se activa la alarma"
  type        = number
  default     = 5
}

variable "monitoring_rds_connections_threshold" {
  description = "Numero maximo de conexiones activas a RDS antes de activar la alarma"
  type        = number
  default     = 100
}
