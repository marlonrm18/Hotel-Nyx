output "svc_reservas_repository_url" {
  description = "URL del repositorio ECR svc-reservas (para docker push/pull)"
  value       = aws_ecr_repository.svc_reservas.repository_url
}

output "svc_pagos_repository_url" {
  description = "URL del repositorio ECR svc-pagos (para docker push/pull)"
  value       = aws_ecr_repository.svc_pagos.repository_url
}
