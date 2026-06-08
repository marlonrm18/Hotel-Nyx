# CloudWatch Logs requiere que el key policy incluya explicitamente
# el servicio logs.<region>.amazonaws.com, de ahi el policy dedicado.

data "aws_iam_policy_document" "ecs_logs_kms" {
  statement {
    sid     = "RootAccess"
    effect  = "Allow"
    actions = ["kms:*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    resources = ["*"]
  }

  statement {
    sid    = "AllowCloudWatchLogs"
    effect = "Allow"
    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*",
    ]
    principals {
      type        = "Service"
      identifiers = ["logs.${var.aws_region}.amazonaws.com"]
    }
    resources = ["*"]
    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:${data.aws_partition.current.partition}:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"]
    }
  }
}

resource "aws_kms_key" "ecs_logs" {
  description             = "${var.project}-${var.environment}: cifrado logs ECS"
  policy                  = data.aws_iam_policy_document.ecs_logs_kms.json
  deletion_window_in_days = var.kms_deletion_window_days
  enable_key_rotation     = true

  tags = { Name = "${var.project}-${var.environment}-kms-ecs-logs" }
}

resource "aws_kms_alias" "ecs_logs" {
  name          = "alias/${var.project}-${var.environment}-ecs-logs"
  target_key_id = aws_kms_key.ecs_logs.key_id
}

# ─── CloudWatch Log Groups ────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "svc_reservas" {
  name              = "/ecs/${var.project}-${var.environment}/svc-reservas"
  retention_in_days = var.ecs_log_retention_days
  kms_key_id        = aws_kms_key.ecs_logs.arn

  tags = { Service = "svc-reservas" }
}

resource "aws_cloudwatch_log_group" "svc_pagos" {
  name              = "/ecs/${var.project}-${var.environment}/svc-pagos"
  retention_in_days = var.ecs_log_retention_days
  kms_key_id        = aws_kms_key.ecs_logs.arn

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

locals {
  reservas_secrets = [
    { name = "DB_SECRET_ARN", valueFrom = aws_secretsmanager_secret.rds.arn },
  ]

  pagos_secrets = [
    { name = "DB_SECRET_ARN", valueFrom = aws_secretsmanager_secret.rds.arn },
  ]
}

# ─── Task Definition: svc-reservas ───────────────────────────────────────────
# 0.25 vCPU (256) / 512 MB

resource "aws_ecs_task_definition" "reservas" {
  family                   = "${var.project}-${var.environment}-svc-reservas"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.svc_reservas_task.arn

  container_definitions = jsonencode([
    {
      name      = "svc-reservas"
      image     = "${aws_ecr_repository.svc_reservas.repository_url}:${var.ecs_reservas_image_tag}"
      essential = true

      portMappings = [
        { containerPort = 3000, protocol = "tcp" }
      ]

      environment = [
        { name = "PORT", value = "3000" },
        { name = "NODE_ENV", value = var.environment },
        { name = "DOMAIN_NAME", value = var.domain_name },
      ]

      secrets = local.reservas_secrets

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
# 0.50 vCPU (512) / 1024 MB

resource "aws_ecs_task_definition" "pagos" {
  family                   = "${var.project}-${var.environment}-svc-pagos"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.svc_pagos_task.arn

  container_definitions = jsonencode([
    {
      name      = "svc-pagos"
      image     = "${aws_ecr_repository.svc_pagos.repository_url}:${var.ecs_pagos_image_tag}"
      essential = true

      portMappings = [
        { containerPort = 3001, protocol = "tcp" }
      ]

      environment = [
        { name = "PORT", value = "3001" },
        { name = "NODE_ENV", value = var.environment },
      ]

      secrets = local.pagos_secrets

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
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.reservas.arn
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

  depends_on = [
    aws_lb_listener.https,
    aws_iam_role_policy_attachment.ecs_task_execution_managed,
  ]

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
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.pagos.arn
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

  depends_on = [
    aws_lb_listener.https,
    aws_iam_role_policy_attachment.ecs_task_execution_managed,
  ]

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
      resource_label         = "${aws_lb.main.arn_suffix}/${aws_lb_target_group.reservas.arn_suffix}"
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
      resource_label         = "${aws_lb.main.arn_suffix}/${aws_lb_target_group.pagos.arn_suffix}"
    }
  }
}
