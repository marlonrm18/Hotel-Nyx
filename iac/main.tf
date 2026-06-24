# ─────────────────────────────────────────────────────────────────────────────
# Hotel Nyx — Root module: cablea todos los módulos de la arquitectura.
# Región principal us-east-2 (Ohio); alias us-east-1 para el cert de CloudFront.
# ─────────────────────────────────────────────────────────────────────────────

locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition
}

# ═══ Capa 0: módulos base sin dependencias ══════════════════════════════════

module "networking" {
  source = "./modules/networking"

  project              = var.project
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  single_nat_gateway   = var.single_nat_gateway
}

module "kms" {
  source = "./modules/kms"

  project                  = var.project
  environment              = var.environment
  kms_deletion_window_days = var.kms_deletion_window_days
  aws_region               = var.aws_region
  account_id               = local.account_id
  partition                = local.partition
}

module "cognito" {
  source = "./modules/cognito"

  project                        = var.project
  environment                    = var.environment
  cognito_password_min_length    = var.cognito_password_min_length
  cognito_mfa_configuration      = var.cognito_mfa_configuration
  cognito_advanced_security_mode = var.cognito_advanced_security_mode
  cognito_callback_urls          = var.cognito_callback_urls
  cognito_logout_urls            = var.cognito_logout_urls
}

# ═══ Capa 1: dependen de redes / KMS ════════════════════════════════════════

module "security_groups" {
  source = "./modules/security_groups"

  project     = var.project
  environment = var.environment
  vpc_id      = module.networking.vpc_id
}

module "ecr" {
  source = "./modules/ecr"

  project                   = var.project
  environment               = var.environment
  ecr_image_retention_count = var.ecr_image_retention_count
  ecr_kms_key_arn           = module.kms.ecr_key_arn
}

module "route53" {
  source = "./modules/route53"

  project     = var.project
  environment = var.environment
  domain_name = var.domain_name
}

# ═══ Capa 2: RDS ════════════════════════════════════════════════════════════

module "rds" {
  source = "./modules/rds"

  project                            = var.project
  environment                        = var.environment
  partition                          = local.partition
  private_subnet_ids                 = module.networking.private_subnet_ids
  rds_sg_id                          = module.security_groups.rds_sg_id
  rds_kms_key_arn                    = module.kms.rds_key_arn
  rds_postgres_version               = var.rds_postgres_version
  rds_instance_class                 = var.rds_instance_class
  rds_allocated_storage              = var.rds_allocated_storage
  rds_max_allocated_storage          = var.rds_max_allocated_storage
  rds_db_name                        = var.rds_db_name
  rds_master_username                = var.rds_master_username
  rds_backup_retention_days          = var.rds_backup_retention_days
  rds_deletion_protection            = var.rds_deletion_protection
  rds_skip_final_snapshot            = var.rds_skip_final_snapshot
  rds_performance_insights_retention = var.rds_performance_insights_retention
}

# ═══ Capa 3: Secrets Manager (rds + mercadopago) ════════════════════════════

module "secrets" {
  source = "./modules/secrets"

  project                      = var.project
  environment                  = var.environment
  secrets_recovery_window_days = var.secrets_recovery_window_days
  rds_kms_key_arn              = module.kms.rds_key_arn
  db_host                      = module.rds.db_address
  db_port                      = module.rds.db_port
  db_name                      = var.rds_db_name
  db_username                  = var.rds_master_username
  db_password                  = module.rds.db_password
}

# ═══ Capa 4: IAM (roles ECS) ════════════════════════════════════════════════

module "iam" {
  source = "./modules/iam"

  project                = var.project
  environment            = var.environment
  aws_region             = var.aws_region
  account_id             = local.account_id
  partition              = local.partition
  domain_name            = var.domain_name
  rds_secret_arn         = module.secrets.rds_secret_arn
  mercadopago_secret_arn = module.secrets.mercadopago_secret_arn
  rds_kms_key_arn        = module.kms.rds_key_arn
}

# ═══ Capa 5: ALB + ACM regional ═════════════════════════════════════════════

module "alb" {
  source = "./modules/alb"

  project                    = var.project
  environment                = var.environment
  domain_name                = var.domain_name
  route53_zone_id            = module.route53.zone_id
  vpc_id                     = module.networking.vpc_id
  public_subnet_ids          = module.networking.public_subnet_ids
  alb_sg_id                  = module.security_groups.alb_sg_id
  alb_access_logs_bucket     = var.alb_access_logs_bucket
  alb_health_check_path      = var.alb_health_check_path
  alb_reservas_path_patterns = var.alb_reservas_path_patterns
  alb_pagos_path_patterns    = var.alb_pagos_path_patterns
}

# ═══ Capa 6: ECS (cluster, task defs, servicios, autoscaling) ═══════════════
# depends_on a nivel de módulo preserva el orden del original: los servicios
# arrancan tras el listener HTTPS (módulo alb) y tras adjuntar la managed
# policy del execution role (módulo iam).

module "ecs" {
  source = "./modules/ecs"

  project     = var.project
  environment = var.environment
  aws_region  = var.aws_region
  domain_name = var.domain_name

  ecs_logs_key_arn            = module.kms.ecs_logs_key_arn
  svc_reservas_repository_url = module.ecr.svc_reservas_repository_url
  svc_pagos_repository_url    = module.ecr.svc_pagos_repository_url
  rds_secret_arn              = module.secrets.rds_secret_arn
  mercadopago_secret_arn      = module.secrets.mercadopago_secret_arn
  ecs_execution_role_arn      = module.iam.ecs_execution_role_arn
  svc_reservas_task_role_arn  = module.iam.svc_reservas_task_role_arn
  svc_pagos_task_role_arn     = module.iam.svc_pagos_task_role_arn
  private_subnet_ids          = module.networking.private_subnet_ids
  ecs_sg_id                   = module.security_groups.ecs_sg_id
  tg_reservas_arn             = module.alb.tg_reservas_arn
  tg_pagos_arn                = module.alb.tg_pagos_arn
  alb_arn_suffix              = module.alb.alb_arn_suffix
  tg_reservas_arn_suffix      = module.alb.tg_reservas_arn_suffix
  tg_pagos_arn_suffix         = module.alb.tg_pagos_arn_suffix

  mp_notification_url         = var.mp_notification_url
  ecs_reservas_image_tag      = var.ecs_reservas_image_tag
  ecs_pagos_image_tag         = var.ecs_pagos_image_tag
  ecs_reservas_cpu            = var.ecs_reservas_cpu
  ecs_reservas_memory         = var.ecs_reservas_memory
  ecs_pagos_cpu               = var.ecs_pagos_cpu
  ecs_pagos_memory            = var.ecs_pagos_memory
  ecs_reservas_min_capacity   = var.ecs_reservas_min_capacity
  ecs_reservas_max_capacity   = var.ecs_reservas_max_capacity
  ecs_pagos_min_capacity      = var.ecs_pagos_min_capacity
  ecs_pagos_max_capacity      = var.ecs_pagos_max_capacity
  ecs_cpu_scale_target        = var.ecs_cpu_scale_target
  ecs_alb_requests_per_target = var.ecs_alb_requests_per_target
  ecs_enable_execute_command  = var.ecs_enable_execute_command
  ecs_log_retention_days      = var.ecs_log_retention_days

  depends_on = [module.alb, module.iam]
}

# ═══ Capa 7: frontend, api_gateway, ses ═════════════════════════════════════

module "frontend" {
  source = "./modules/frontend"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  project                      = var.project
  environment                  = var.environment
  domain_name                  = var.domain_name
  account_id                   = local.account_id
  partition                    = local.partition
  frontend_key_arn             = module.kms.frontend_key_arn
  frontend_key_id              = module.kms.frontend_key_id
  cert_validation_record_fqdns = module.alb.cert_validation_record_fqdns
  route53_zone_id              = module.route53.zone_id
  s3_frontend_force_destroy    = var.s3_frontend_force_destroy
  cloudfront_price_class       = var.cloudfront_price_class
}

module "api_gateway" {
  source = "./modules/api_gateway"

  project                    = var.project
  environment                = var.environment
  aws_region                 = var.aws_region
  domain_name                = var.domain_name
  ecs_logs_key_arn           = module.kms.ecs_logs_key_arn
  ecs_log_retention_days     = var.ecs_log_retention_days
  cognito_user_pool_id       = module.cognito.user_pool_id
  cognito_client_id          = module.cognito.client_id
  alb_dns_name               = module.alb.alb_dns_name
  acm_certificate_arn        = module.alb.acm_certificate_arn
  route53_zone_id            = module.route53.zone_id
  api_cors_allow_origins     = var.api_cors_allow_origins
  api_throttling_burst_limit = var.api_throttling_burst_limit
  api_throttling_rate_limit  = var.api_throttling_rate_limit
}

module "ses" {
  source = "./modules/ses"

  project             = var.project
  environment         = var.environment
  aws_region          = var.aws_region
  domain_name         = var.domain_name
  alert_email         = var.alert_email
  route53_zone_id     = module.route53.zone_id
  vpc_id              = module.networking.vpc_id
  private_subnet_ids  = module.networking.private_subnet_ids
  vpc_endpoints_sg_id = module.security_groups.vpc_endpoints_sg_id
}

# ═══ Capa 8: monitoring (SNS + alarmas + dashboard) ═════════════════════════

module "monitoring" {
  source = "./modules/monitoring"

  project           = var.project
  environment       = var.environment
  aws_region        = var.aws_region
  account_id        = local.account_id
  partition         = local.partition
  alert_email       = var.alert_email
  monitoring_key_id = module.kms.monitoring_key_id

  alb_arn_suffix            = module.alb.alb_arn_suffix
  tg_reservas_arn_suffix    = module.alb.tg_reservas_arn_suffix
  tg_pagos_arn_suffix       = module.alb.tg_pagos_arn_suffix
  ecs_cluster_name          = module.ecs.cluster_name
  ecs_service_reservas_name = module.ecs.service_reservas_name
  ecs_service_pagos_name    = module.ecs.service_pagos_name
  rds_identifier            = module.rds.db_identifier
  api_id                    = module.api_gateway.api_id

  monitoring_alarm_5xx_threshold        = var.monitoring_alarm_5xx_threshold
  monitoring_alarm_latency_threshold_ms = var.monitoring_alarm_latency_threshold_ms
  monitoring_ecs_cpu_threshold          = var.monitoring_ecs_cpu_threshold
  monitoring_rds_cpu_threshold          = var.monitoring_rds_cpu_threshold
  monitoring_rds_free_storage_gb        = var.monitoring_rds_free_storage_gb
  monitoring_rds_connections_threshold  = var.monitoring_rds_connections_threshold
}
