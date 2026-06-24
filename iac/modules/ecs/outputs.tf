output "cluster_arn" {
  description = "ARN del cluster ECS Fargate"
  value       = aws_ecs_cluster.main.arn
}

output "cluster_name" {
  description = "Nombre del cluster ECS"
  value       = aws_ecs_cluster.main.name
}

output "service_reservas_name" {
  description = "Nombre del servicio ECS svc-reservas"
  value       = aws_ecs_service.reservas.name
}

output "service_pagos_name" {
  description = "Nombre del servicio ECS svc-pagos"
  value       = aws_ecs_service.pagos.name
}
