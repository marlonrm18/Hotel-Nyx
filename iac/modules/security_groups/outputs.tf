output "alb_sg_id" {
  description = "ID del Security Group del ALB"
  value       = aws_security_group.alb.id
}

output "ecs_sg_id" {
  description = "ID del Security Group de las tareas ECS Fargate"
  value       = aws_security_group.ecs.id
}

output "rds_sg_id" {
  description = "ID del Security Group de RDS PostgreSQL"
  value       = aws_security_group.rds.id
}

output "vpc_endpoints_sg_id" {
  description = "ID del Security Group de los VPC Interface Endpoints (PrivateLink)"
  value       = aws_security_group.vpc_endpoints.id
}
