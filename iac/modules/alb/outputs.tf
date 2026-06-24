output "acm_certificate_arn" {
  description = "ARN del certificado ACM us-east-2 validado (ALB + API Gateway Regional)"
  value       = aws_acm_certificate_validation.main.certificate_arn
}

output "cert_validation_record_fqdns" {
  description = "FQDNs de los registros CNAME de validación (reutilizados por el cert de CloudFront)"
  value       = [for r in aws_route53_record.cert_validation : r.fqdn]
}

output "alb_arn" {
  description = "ARN del ALB"
  value       = aws_lb.main.arn
}

output "alb_dns_name" {
  description = "DNS name del ALB (usado por API Gateway como backend)"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Hosted zone ID del ALB (para registros Route 53 alias)"
  value       = aws_lb.main.zone_id
}

output "alb_arn_suffix" {
  description = "Sufijo del ARN del ALB (para dimensiones de métricas CloudWatch)"
  value       = aws_lb.main.arn_suffix
}

output "listener_https_arn" {
  description = "ARN del listener HTTPS 443 (dependencia de los servicios ECS)"
  value       = aws_lb_listener.https.arn
}

output "tg_reservas_arn" {
  description = "ARN del target group de svc-reservas"
  value       = aws_lb_target_group.reservas.arn
}

output "tg_pagos_arn" {
  description = "ARN del target group de svc-pagos"
  value       = aws_lb_target_group.pagos.arn
}

output "tg_reservas_arn_suffix" {
  description = "Sufijo del ARN del target group reservas (métricas / autoscaling)"
  value       = aws_lb_target_group.reservas.arn_suffix
}

output "tg_pagos_arn_suffix" {
  description = "Sufijo del ARN del target group pagos (métricas / autoscaling)"
  value       = aws_lb_target_group.pagos.arn_suffix
}
