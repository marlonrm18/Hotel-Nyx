# ─── VPC ─────────────────────────────────────────────────────────────────────

output "vpc_id" {
  description = "ID de la VPC principal"
  value       = module.networking.vpc_id
}

output "vpc_cidr" {
  description = "Bloque CIDR de la VPC"
  value       = module.networking.vpc_cidr
}

output "public_subnet_ids" {
  description = "IDs de las subnets públicas (índice = AZ)"
  value       = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs de las subnets privadas (índice = AZ)"
  value       = module.networking.private_subnet_ids
}

output "nat_gateway_ids" {
  description = "IDs de los NAT Gateways"
  value       = module.networking.nat_gateway_ids
}

output "nat_gateway_public_ips" {
  description = "IPs públicas de los NAT Gateways (whitelisting en servicios externos)"
  value       = module.networking.nat_gateway_public_ips
}

# ─── Security Groups ──────────────────────────────────────────────────────────

output "sg_alb_id" {
  description = "ID del Security Group del ALB"
  value       = module.security_groups.alb_sg_id
}

output "sg_ecs_id" {
  description = "ID del Security Group de las tareas ECS Fargate"
  value       = module.security_groups.ecs_sg_id
}

output "sg_rds_id" {
  description = "ID del Security Group de RDS PostgreSQL"
  value       = module.security_groups.rds_sg_id
}

output "sg_vpc_endpoints_id" {
  description = "ID del Security Group de los VPC Interface Endpoints (PrivateLink)"
  value       = module.security_groups.vpc_endpoints_sg_id
}

# ─── ECR ─────────────────────────────────────────────────────────────────────

output "ecr_svc_reservas_url" {
  description = "URL del repositorio ECR svc-reservas (para docker push/pull)"
  value       = module.ecr.svc_reservas_repository_url
}

output "ecr_svc_pagos_url" {
  description = "URL del repositorio ECR svc-pagos (para docker push/pull)"
  value       = module.ecr.svc_pagos_repository_url
}

output "kms_ecr_arn" {
  description = "ARN de la KMS key usada para cifrar los repositorios ECR"
  value       = module.kms.ecr_key_arn
}

# ─── Route 53 ────────────────────────────────────────────────────────────────

output "route53_zone_id" {
  description = "ID de la hosted zone Route 53"
  value       = module.route53.zone_id
}

output "route53_name_servers" {
  description = "Name servers de la hosted zone (delegar desde el registrar)"
  value       = module.route53.name_servers
}

# ─── ACM / ALB ───────────────────────────────────────────────────────────────

output "acm_certificate_arn" {
  description = "ARN del certificado ACM us-east-2 (ALB + API Gateway Regional)"
  value       = module.alb.acm_certificate_arn
}

output "alb_dns_name" {
  description = "DNS name del ALB (usado por API Gateway como backend)"
  value       = module.alb.alb_dns_name
}

output "alb_zone_id" {
  description = "Hosted zone ID del ALB (para registros Route 53 alias)"
  value       = module.alb.alb_zone_id
}

output "alb_arn" {
  description = "ARN del ALB"
  value       = module.alb.alb_arn
}

output "tg_reservas_arn" {
  description = "ARN del target group de svc-reservas"
  value       = module.alb.tg_reservas_arn
}

output "tg_pagos_arn" {
  description = "ARN del target group de svc-pagos"
  value       = module.alb.tg_pagos_arn
}

output "alb_listener_https_arn" {
  description = "ARN del listener HTTPS 443"
  value       = module.alb.listener_https_arn
}

# ─── ECS ─────────────────────────────────────────────────────────────────────

output "ecs_cluster_arn" {
  description = "ARN del cluster ECS Fargate"
  value       = module.ecs.cluster_arn
}

output "ecs_cluster_name" {
  description = "Nombre del cluster ECS"
  value       = module.ecs.cluster_name
}

output "ecs_service_reservas_name" {
  description = "Nombre del servicio ECS svc-reservas"
  value       = module.ecs.service_reservas_name
}

output "ecs_service_pagos_name" {
  description = "Nombre del servicio ECS svc-pagos"
  value       = module.ecs.service_pagos_name
}

# ─── IAM ─────────────────────────────────────────────────────────────────────

output "iam_ecs_execution_role_arn" {
  description = "ARN del task execution role compartido de ECS"
  value       = module.iam.ecs_execution_role_arn
}

output "iam_svc_reservas_task_role_arn" {
  description = "ARN del task role de svc-reservas"
  value       = module.iam.svc_reservas_task_role_arn
}

output "iam_svc_pagos_task_role_arn" {
  description = "ARN del task role de svc-pagos"
  value       = module.iam.svc_pagos_task_role_arn
}

# ─── RDS ─────────────────────────────────────────────────────────────────────

output "rds_endpoint" {
  description = "Endpoint de conexion a RDS (host:port)"
  value       = module.rds.db_endpoint
}

output "rds_address" {
  description = "Hostname del RDS (sin puerto)"
  value       = module.rds.db_address
}

output "rds_port" {
  description = "Puerto de RDS"
  value       = module.rds.db_port
}

output "rds_secret_arn" {
  description = "ARN del Secrets Manager secret con credenciales de RDS"
  value       = module.secrets.rds_secret_arn
}

output "kms_rds_arn" {
  description = "ARN de la KMS key usada para cifrar RDS y su secret"
  value       = module.kms.rds_key_arn
}

# ─── Cognito ──────────────────────────────────────────────────────────────────

output "cognito_user_pool_id" {
  description = "ID del User Pool de Cognito"
  value       = module.cognito.user_pool_id
}

output "cognito_user_pool_arn" {
  description = "ARN del User Pool (usado por API Gateway Cognito authorizer)"
  value       = module.cognito.user_pool_arn
}

output "cognito_client_id" {
  description = "ID del app client de Cognito"
  value       = module.cognito.client_id
}

output "cognito_issuer_url" {
  description = "Issuer URL del JWT (para configurar el authorizer de API Gateway)"
  value       = "https://cognito-idp.${var.aws_region}.amazonaws.com/${module.cognito.user_pool_id}"
}

output "cognito_hosted_ui_url" {
  description = "URL base de la hosted UI de Cognito"
  value       = "https://${module.cognito.user_pool_domain}.auth.${var.aws_region}.amazoncognito.com"
}

output "cognito_scope_guest_reserve" {
  description = "Scope completo para reservas de huespedes"
  value       = "hotel-api/guest:reserve"
}

output "cognito_scope_admin_write" {
  description = "Scope completo para operaciones administrativas"
  value       = "hotel-api/admin:write"
}

# ─── API Gateway ─────────────────────────────────────────────────────────────

output "api_gateway_id" {
  description = "ID de la HTTP API"
  value       = module.api_gateway.api_id
}

output "api_gateway_endpoint" {
  description = "Endpoint por defecto de la API (antes del dominio custom)"
  value       = module.api_gateway.api_endpoint
}

output "api_custom_domain_url" {
  description = "URL publica de la API con dominio custom"
  value       = "https://api.${var.domain_name}"
}

output "api_gateway_domain_name" {
  description = "DNS name del dominio custom API Gateway (para registro Route 53 alias)"
  value       = module.api_gateway.domain_target_domain_name
}

output "api_gateway_domain_zone_id" {
  description = "Hosted zone ID del dominio API Gateway (para registro Route 53 alias)"
  value       = module.api_gateway.domain_hosted_zone_id
}

# ─── CloudFront / Frontend ────────────────────────────────────────────────────

output "s3_frontend_bucket_name" {
  description = "Nombre del bucket S3 del frontend estatico"
  value       = module.frontend.bucket_name
}

output "s3_frontend_bucket_arn" {
  description = "ARN del bucket S3 del frontend"
  value       = module.frontend.bucket_arn
}

output "cloudfront_distribution_id" {
  description = "ID de la distribucion CloudFront (para invalidaciones de cache)"
  value       = module.frontend.distribution_id
}

output "cloudfront_distribution_arn" {
  description = "ARN de la distribucion CloudFront"
  value       = module.frontend.distribution_arn
}

output "cloudfront_domain_name" {
  description = "Dominio CloudFront asignado por AWS (para alias en Route 53)"
  value       = module.frontend.distribution_domain_name
}

output "cloudfront_hosted_zone_id" {
  description = "Hosted zone ID de CloudFront (siempre Z2FDTNDATAQYW2)"
  value       = module.frontend.distribution_hosted_zone_id
}

output "acm_cloudfront_certificate_arn" {
  description = "ARN del certificado ACM en us-east-1 para CloudFront"
  value       = module.frontend.acm_certificate_arn
}

output "kms_frontend_arn" {
  description = "ARN de la KMS key usada para cifrar el bucket S3 del frontend"
  value       = module.kms.frontend_key_arn
}

# ─── SES ─────────────────────────────────────────────────────────────────────

output "ses_domain_identity_arn" {
  description = "ARN de la identidad de dominio SES (usado en políticas IAM)"
  value       = module.ses.domain_identity_arn
}

output "ses_domain_verification_token" {
  description = "Token TXT de verificación SES (ya publicado en Route 53)"
  value       = module.ses.verification_token
}

output "ses_mail_from_domain" {
  description = "Subdominio MAIL FROM configurado para SES"
  value       = module.ses.mail_from_domain
}

output "ses_vpc_endpoint_id" {
  description = "ID del VPC Interface Endpoint de SES (PrivateLink)"
  value       = module.ses.vpc_endpoint_id
}

output "ses_vpc_endpoint_dns" {
  description = "DNS privado del endpoint SES"
  value       = module.ses.vpc_endpoint_dns
}

# ─── Secrets Manager ──────────────────────────────────────────────────────────

output "mercadopago_secret_arn" {
  description = "ARN del secret de Mercado Pago (cargar el valor real por CLI)"
  value       = module.secrets.mercadopago_secret_arn
}

# ─── Monitoring ───────────────────────────────────────────────────────────────

output "sns_alerts_arn" {
  description = "ARN del topic SNS de alertas (suscribir canales adicionales)"
  value       = module.monitoring.sns_alerts_arn
}

output "cloudwatch_dashboard_name" {
  description = "Nombre del dashboard CloudWatch"
  value       = module.monitoring.dashboard_name
}

output "cloudwatch_dashboard_url" {
  description = "URL directa al dashboard en la consola AWS"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${module.monitoring.dashboard_name}"
}

output "kms_monitoring_arn" {
  description = "ARN de la KMS key usada para cifrar el topic SNS de alertas"
  value       = module.kms.monitoring_key_arn
}
