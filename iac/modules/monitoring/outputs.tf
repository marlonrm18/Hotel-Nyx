output "sns_alerts_arn" {
  description = "ARN del topic SNS de alertas (suscribir canales adicionales)"
  value       = aws_sns_topic.alerts.arn
}

output "dashboard_name" {
  description = "Nombre del dashboard CloudWatch"
  value       = aws_cloudwatch_dashboard.main.dashboard_name
}
