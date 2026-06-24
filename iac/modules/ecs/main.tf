# ─── CloudWatch Log Groups ────────────────────────────────────────────────────
# Cifrados con la CMK ecs_logs (su key policy autoriza a CloudWatch Logs).

resource "aws_cloudwatch_log_group" "svc_reservas" {
  name              = "/ecs/${var.project}-${var.environment}/svc-reservas"
  retention_in_days = var.ecs_log_retention_days
  kms_key_id        = var.ecs_logs_key_arn

  tags = { Service = "svc-reservas" }
}

resource "aws_cloudwatch_log_group" "svc_pagos" {
  name              = "/ecs/${var.project}-${var.environment}/svc-pagos"
  retention_in_days = var.ecs_log_retention_days
  kms_key_id        = var.ecs_logs_key_arn

  tags = { Service = "svc-pagos" }
}

# ─── ECS Cluster ─────────────────────────────────────────────────────────────

resource "aws_ecs_cluster" "main" {
  name = "${var.project}-${var.environment}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = { Name = "${var.project}-${var.environment}-cluster" }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
    base              = 0
  }
}

# ─── Task Definition: svc-reservas ───────────────────────────────────────────
# Tamaño mínimo por defecto: 0.25 vCPU (256) / 512 MB (variables ecs_reservas_*).

resource "aws_ecs_task_definition" "reservas" {
  family                   = "${var.project}-${var.environment}-svc-reservas"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.ecs_reservas_cpu
  memory                   = var.ecs_reservas_memory
  execution_role_arn       = var.ecs_execution_role_arn
  task_role_arn            = var.svc_reservas_task_role_arn

  container_definitions = jsonencode([
    {
      name      = "svc-reservas"
      image     = "${var.svc_reservas_repository_url}:${var.ecs_reservas_image_tag}"
      essential = true

      portMappings = [
        { containerPort = 3000, protocol = "tcp" }
      ]

      environment = [
        { name = "PORT", value = "3000" },
        { name = "NODE_ENV", value = var.environment },
        { name = "DOMAIN_NAME", value = var.domain_name },
        # ARN (no el valor) del secret de RDS. svc-reservas lo resuelve en runtime
        # con su task role (GetSecretValue + kms:Decrypt sobre la CMK del RDS), no
        # via `secrets`/valueFrom: la app llama GetSecretValue con este ARN.
        { name = "DB_SECRET_ARN", value = var.rds_secret_arn },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.svc_reservas.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      readonlyRootFilesystem = true

      healthCheck = {
        command     = ["CMD-SHELL", "curl -sf http://localhost:3000/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = {
    Name    = "${var.project}-${var.environment}-td-svc-reservas"
    Service = "svc-reservas"
  }
}

# ─── Task Definition: svc-pagos ──────────────────────────────────────────────
# Tamaño por defecto: 0.50 vCPU (512) / 1024 MB (variables ecs_pagos_*).

resource "aws_ecs_task_definition" "pagos" {
  family                   = "${var.project}-${var.environment}-svc-pagos"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.ecs_pagos_cpu
  memory                   = var.ecs_pagos_memory
  execution_role_arn       = var.ecs_execution_role_arn
  task_role_arn            = var.svc_pagos_task_role_arn

  container_definitions = jsonencode([
    {
      name      = "svc-pagos"
      image     = "${var.svc_pagos_repository_url}:${var.ecs_pagos_image_tag}"
      essential = true

      portMappings = [
        { containerPort = 3001, protocol = "tcp" }
      ]

      environment = [
        { name = "PORT", value = "3001" },
        { name = "NODE_ENV", value = var.environment },
        { name = "DOMAIN_NAME", value = var.domain_name },
        # Remitente verificado bajo la identidad SES del dominio (módulo ses).
        { name = "MAIL_FROM", value = "Hotel Nyx <no-reply@${var.domain_name}>" },
        # Base del frontend para las back_urls de Mercado Pago (CloudFront).
        { name = "APP_BASE_URL", value = "https://${var.domain_name}" },
        # PLACEHOLDER hasta el apply: se rellena con la URL real del API Gateway.
        { name = "MP_NOTIFICATION_URL", value = var.mp_notification_url },
        # ARN (no el valor) del secret de Mercado Pago; svc-pagos lo resuelve en
        # runtime con su task role (GetSecretValue). Ver módulos secrets/iam.
        { name = "MP_SECRET_ARN", value = var.mercadopago_secret_arn },
        # ARN (no el valor) del secret de RDS. svc-pagos lo resuelve en runtime
        # con su task role (GetSecretValue + kms:Decrypt sobre la CMK del RDS), no
        # via `secrets`/valueFrom: la app llama GetSecretValue con este ARN.
        { name = "DB_SECRET_ARN", value = var.rds_secret_arn },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.svc_pagos.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      readonlyRootFilesystem = true

      healthCheck = {
        command     = ["CMD-SHELL", "curl -sf http://localhost:3001/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = {
    Name    = "${var.project}-${var.environment}-td-svc-pagos"
    Service = "svc-pagos"
  }
}

# ─── ECS Service: svc-reservas ───────────────────────────────────────────────

resource "aws_ecs_service" "reservas" {
  name                   = "${var.project}-${var.environment}-svc-reservas"
  cluster                = aws_ecs_cluster.main.id
  task_definition        = aws_ecs_task_definition.reservas.arn
  desired_count          = var.ecs_reservas_min_capacity
  launch_type            = "FARGATE"
  platform_version       = "LATEST"
  enable_execute_command = var.ecs_enable_execute_command

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_sg_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.tg_reservas_arn
    container_name   = "svc-reservas"
    container_port   = 3000
  }

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  # Auto-scaling gestiona desired_count; ignorarlo evita conflictos con Terraform.
  lifecycle {
    ignore_changes = [desired_count]
  }

  tags = {
    Name    = "${var.project}-${var.environment}-svc-reservas"
    Service = "svc-reservas"
  }
}

# ─── ECS Service: svc-pagos ──────────────────────────────────────────────────

resource "aws_ecs_service" "pagos" {
  name                   = "${var.project}-${var.environment}-svc-pagos"
  cluster                = aws_ecs_cluster.main.id
  task_definition        = aws_ecs_task_definition.pagos.arn
  desired_count          = var.ecs_pagos_min_capacity
  launch_type            = "FARGATE"
  platform_version       = "LATEST"
  enable_execute_command = var.ecs_enable_execute_command

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_sg_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.tg_pagos_arn
    container_name   = "svc-pagos"
    container_port   = 3001
  }

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  lifecycle {
    ignore_changes = [desired_count]
  }

  tags = {
    Name    = "${var.project}-${var.environment}-svc-pagos"
    Service = "svc-pagos"
  }
}

# ─── Application Auto Scaling ─────────────────────────────────────────────────

resource "aws_appautoscaling_target" "reservas" {
  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.reservas.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = var.ecs_reservas_min_capacity
  max_capacity       = var.ecs_reservas_max_capacity
}

resource "aws_appautoscaling_target" "pagos" {
  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.pagos.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = var.ecs_pagos_min_capacity
  max_capacity       = var.ecs_pagos_max_capacity
}

resource "aws_appautoscaling_policy" "reservas_cpu" {
  name               = "${var.project}-${var.environment}-reservas-cpu"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = aws_appautoscaling_target.reservas.service_namespace
  resource_id        = aws_appautoscaling_target.reservas.resource_id
  scalable_dimension = aws_appautoscaling_target.reservas.scalable_dimension

  target_tracking_scaling_policy_configuration {
    target_value       = var.ecs_cpu_scale_target
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

resource "aws_appautoscaling_policy" "reservas_requests" {
  name               = "${var.project}-${var.environment}-reservas-requests"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = aws_appautoscaling_target.reservas.service_namespace
  resource_id        = aws_appautoscaling_target.reservas.resource_id
  scalable_dimension = aws_appautoscaling_target.reservas.scalable_dimension

  target_tracking_scaling_policy_configuration {
    target_value       = var.ecs_alb_requests_per_target
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = "${var.alb_arn_suffix}/${var.tg_reservas_arn_suffix}"
    }
  }
}

resource "aws_appautoscaling_policy" "pagos_cpu" {
  name               = "${var.project}-${var.environment}-pagos-cpu"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = aws_appautoscaling_target.pagos.service_namespace
  resource_id        = aws_appautoscaling_target.pagos.resource_id
  scalable_dimension = aws_appautoscaling_target.pagos.scalable_dimension

  target_tracking_scaling_policy_configuration {
    target_value       = var.ecs_cpu_scale_target
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

resource "aws_appautoscaling_policy" "pagos_requests" {
  name               = "${var.project}-${var.environment}-pagos-requests"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = aws_appautoscaling_target.pagos.service_namespace
  resource_id        = aws_appautoscaling_target.pagos.resource_id
  scalable_dimension = aws_appautoscaling_target.pagos.scalable_dimension

  target_tracking_scaling_policy_configuration {
    target_value       = var.ecs_alb_requests_per_target
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = "${var.alb_arn_suffix}/${var.tg_pagos_arn_suffix}"
    }
  }
}
