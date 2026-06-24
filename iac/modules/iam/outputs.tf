output "ecs_execution_role_arn" {
  description = "ARN del task execution role compartido de ECS"
  value       = aws_iam_role.ecs_task_execution.arn
}

output "svc_reservas_task_role_arn" {
  description = "ARN del task role de svc-reservas"
  value       = aws_iam_role.svc_reservas_task.arn
}

output "svc_pagos_task_role_arn" {
  description = "ARN del task role de svc-pagos"
  value       = aws_iam_role.svc_pagos_task.arn
}
