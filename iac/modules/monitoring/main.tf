# ─── SNS Topic: alertas de operaciones ────────────────────────────────────────
# Cifrado con la CMK monitoring (su key policy autoriza a CloudWatch Alarms).

resource "aws_sns_topic" "alerts" {
  name              = "${var.project}-${var.environment}-alerts"
  kms_master_key_id = var.monitoring_key_id

  tags = { Name = "${var.project}-${var.environment}-alerts" }
}

data "aws_iam_policy_document" "sns_alerts" {
  statement {
    sid    = "AllowOwnerManage"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:${var.partition}:iam::${var.account_id}:root"]
    }
    actions   = ["sns:*"]
    resources = [aws_sns_topic.alerts.arn]
  }

  statement {
    sid    = "AllowCloudWatchPublish"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com"]
    }
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.alerts.arn]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [var.account_id]
    }
  }
}

resource "aws_sns_topic_policy" "alerts" {
  arn    = aws_sns_topic.alerts.arn
  policy = data.aws_iam_policy_document.sns_alerts.json
}

# La suscripción email requiere confirmación manual desde el buzón de alert_email.
resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ─── Locals: mapas de servicios para alarmas con for_each ─────────────────────

locals {
  monitored_tgs = {
    reservas = var.tg_reservas_arn_suffix
    pagos    = var.tg_pagos_arn_suffix
  }

  monitored_ecs = {
    reservas = var.ecs_service_reservas_name
    pagos    = var.ecs_service_pagos_name
  }
}

# ─── Alarmas: ALB ─────────────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "alb_5xx_elb" {
  alarm_name          = "${var.project}-${var.environment}-alb-5xx-elb"
  alarm_description   = "ALB generando errores 5xx propios (no del backend)"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_ELB_5XX_Count"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 2
  threshold           = var.monitoring_alarm_5xx_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  dimensions          = { LoadBalancer = var.alb_arn_suffix }
  tags                = { Name = "${var.project}-${var.environment}-alb-5xx-elb" }
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx_target" {
  alarm_name          = "${var.project}-${var.environment}-alb-5xx-target"
  alarm_description   = "Backends ECS respondiendo con errores 5xx"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 2
  threshold           = var.monitoring_alarm_5xx_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  dimensions          = { LoadBalancer = var.alb_arn_suffix }
  tags                = { Name = "${var.project}-${var.environment}-alb-5xx-target" }
}

# TargetResponseTime está en segundos; el threshold variable está en ms.
resource "aws_cloudwatch_metric_alarm" "alb_latency_p99" {
  alarm_name          = "${var.project}-${var.environment}-alb-latency-p99"
  alarm_description   = "Latencia p99 del ALB supera ${var.monitoring_alarm_latency_threshold_ms} ms"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "TargetResponseTime"
  extended_statistic  = "p99"
  period              = 60
  evaluation_periods  = 3
  threshold           = var.monitoring_alarm_latency_threshold_ms / 1000.0
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  dimensions          = { LoadBalancer = var.alb_arn_suffix }
  tags                = { Name = "${var.project}-${var.environment}-alb-latency-p99" }
}

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy" {
  for_each = local.monitored_tgs

  alarm_name          = "${var.project}-${var.environment}-alb-unhealthy-${each.key}"
  alarm_description   = "Hosts unhealthy en target group ${each.key}"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  dimensions = {
    LoadBalancer = var.alb_arn_suffix
    TargetGroup  = each.value
  }
  tags = { Name = "${var.project}-${var.environment}-alb-unhealthy-${each.key}" }
}

# ─── Alarmas: ECS ─────────────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "ecs_cpu" {
  for_each = local.monitored_ecs

  alarm_name          = "${var.project}-${var.environment}-ecs-${each.key}-cpu"
  alarm_description   = "CPU de svc-${each.key} supera el ${var.monitoring_ecs_cpu_threshold}%"
  namespace           = "AWS/ECS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 3
  threshold           = var.monitoring_ecs_cpu_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = each.value
  }
  tags = { Name = "${var.project}-${var.environment}-ecs-${each.key}-cpu" }
}

resource "aws_cloudwatch_metric_alarm" "ecs_memory" {
  for_each = local.monitored_ecs

  alarm_name          = "${var.project}-${var.environment}-ecs-${each.key}-memory"
  alarm_description   = "Memoria de svc-${each.key} supera el ${var.monitoring_ecs_cpu_threshold}%"
  namespace           = "AWS/ECS"
  metric_name         = "MemoryUtilization"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 3
  threshold           = var.monitoring_ecs_cpu_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = each.value
  }
  tags = { Name = "${var.project}-${var.environment}-ecs-${each.key}-memory" }
}

# ─── Alarmas: RDS ─────────────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "${var.project}-${var.environment}-rds-cpu"
  alarm_description   = "CPU de RDS supera el ${var.monitoring_rds_cpu_threshold}%"
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 3
  threshold           = var.monitoring_rds_cpu_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  dimensions          = { DBInstanceIdentifier = var.rds_identifier }
  tags                = { Name = "${var.project}-${var.environment}-rds-cpu" }
}

# FreeStorageSpace está en bytes; el threshold variable está en GiB.
resource "aws_cloudwatch_metric_alarm" "rds_free_storage" {
  alarm_name          = "${var.project}-${var.environment}-rds-free-storage"
  alarm_description   = "Almacenamiento libre de RDS por debajo de ${var.monitoring_rds_free_storage_gb} GiB"
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  statistic           = "Minimum"
  period              = 300
  evaluation_periods  = 2
  threshold           = var.monitoring_rds_free_storage_gb * 1073741824
  comparison_operator = "LessThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  dimensions          = { DBInstanceIdentifier = var.rds_identifier }
  tags                = { Name = "${var.project}-${var.environment}-rds-storage" }
}

resource "aws_cloudwatch_metric_alarm" "rds_connections" {
  alarm_name          = "${var.project}-${var.environment}-rds-connections"
  alarm_description   = "Conexiones activas a RDS superan ${var.monitoring_rds_connections_threshold}"
  namespace           = "AWS/RDS"
  metric_name         = "DatabaseConnections"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 3
  threshold           = var.monitoring_rds_connections_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  dimensions          = { DBInstanceIdentifier = var.rds_identifier }
  tags                = { Name = "${var.project}-${var.environment}-rds-connections" }
}

# FreeableMemory en bytes; umbral hardcodeado a 256 MiB (valor crítico independiente del env).
resource "aws_cloudwatch_metric_alarm" "rds_freeable_memory" {
  alarm_name          = "${var.project}-${var.environment}-rds-freeable-memory"
  alarm_description   = "Memoria libre de RDS por debajo de 256 MiB"
  namespace           = "AWS/RDS"
  metric_name         = "FreeableMemory"
  statistic           = "Minimum"
  period              = 300
  evaluation_periods  = 2
  threshold           = 268435456
  comparison_operator = "LessThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  dimensions          = { DBInstanceIdentifier = var.rds_identifier }
  tags                = { Name = "${var.project}-${var.environment}-rds-memory" }
}

# ─── Alarmas: API Gateway ─────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "apigw_5xx" {
  alarm_name          = "${var.project}-${var.environment}-apigw-5xx"
  alarm_description   = "API Gateway devolviendo errores 5xx"
  namespace           = "AWS/ApiGateway"
  metric_name         = "5XXError"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 2
  threshold           = var.monitoring_alarm_5xx_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  dimensions          = { ApiId = var.api_id, Stage = "$default" }
  tags                = { Name = "${var.project}-${var.environment}-apigw-5xx" }
}

# IntegrationLatency de API GW está en ms, a diferencia de ALB (segundos).
resource "aws_cloudwatch_metric_alarm" "apigw_latency_p99" {
  alarm_name          = "${var.project}-${var.environment}-apigw-latency-p99"
  alarm_description   = "Latencia p99 de integración API GW supera ${var.monitoring_alarm_latency_threshold_ms} ms"
  namespace           = "AWS/ApiGateway"
  metric_name         = "IntegrationLatency"
  extended_statistic  = "p99"
  period              = 60
  evaluation_periods  = 3
  threshold           = var.monitoring_alarm_latency_threshold_ms
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]
  dimensions          = { ApiId = var.api_id, Stage = "$default" }
  tags                = { Name = "${var.project}-${var.environment}-apigw-latency-p99" }
}

# ─── Dashboard ────────────────────────────────────────────────────────────────

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project}-${var.environment}"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 8
        height = 6
        properties = {
          title   = "ALB — Errores 5xx"
          region  = var.aws_region
          view    = "timeSeries"
          stacked = false
          period  = 60
          stat    = "Sum"
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", var.alb_arn_suffix, { label = "ELB 5xx" }],
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", var.alb_arn_suffix, { label = "Target 5xx" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = 0
        width  = 8
        height = 6
        properties = {
          title  = "ALB — Latencia (s)"
          region = var.aws_region
          view   = "timeSeries"
          period = 60
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix, { stat = "p99", label = "p99" }],
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", var.alb_arn_suffix, { stat = "p50", label = "p50" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = 0
        width  = 8
        height = 6
        properties = {
          title  = "ALB — Hosts saludables"
          region = var.aws_region
          view   = "timeSeries"
          period = 60
          stat   = "Minimum"
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", var.alb_arn_suffix, "TargetGroup", var.tg_reservas_arn_suffix, { label = "reservas" }],
            ["AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", var.alb_arn_suffix, "TargetGroup", var.tg_pagos_arn_suffix, { label = "pagos" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "ECS — CPU %"
          region = var.aws_region
          view   = "timeSeries"
          period = 60
          stat   = "Average"
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", var.ecs_cluster_name, "ServiceName", var.ecs_service_reservas_name, { label = "reservas" }],
            ["AWS/ECS", "CPUUtilization", "ClusterName", var.ecs_cluster_name, "ServiceName", var.ecs_service_pagos_name, { label = "pagos" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "ECS — Memoria %"
          region = var.aws_region
          view   = "timeSeries"
          period = 60
          stat   = "Average"
          metrics = [
            ["AWS/ECS", "MemoryUtilization", "ClusterName", var.ecs_cluster_name, "ServiceName", var.ecs_service_reservas_name, { label = "reservas" }],
            ["AWS/ECS", "MemoryUtilization", "ClusterName", var.ecs_cluster_name, "ServiceName", var.ecs_service_pagos_name, { label = "pagos" }]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 6
        height = 6
        properties = {
          title  = "RDS — CPU %"
          region = var.aws_region
          view   = "timeSeries"
          period = 60
          stat   = "Average"
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.rds_identifier]
          ]
        }
      },
      {
        type   = "metric"
        x      = 6
        y      = 12
        width  = 6
        height = 6
        properties = {
          title  = "RDS — Conexiones activas"
          region = var.aws_region
          view   = "timeSeries"
          period = 60
          stat   = "Maximum"
          metrics = [
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", var.rds_identifier]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 12
        width  = 6
        height = 6
        properties = {
          title  = "RDS — Almacenamiento libre (bytes)"
          region = var.aws_region
          view   = "timeSeries"
          period = 300
          stat   = "Minimum"
          metrics = [
            ["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", var.rds_identifier]
          ]
        }
      },
      {
        type   = "metric"
        x      = 18
        y      = 12
        width  = 6
        height = 6
        properties = {
          title  = "RDS — Memoria libre (bytes)"
          region = var.aws_region
          view   = "timeSeries"
          period = 300
          stat   = "Minimum"
          metrics = [
            ["AWS/RDS", "FreeableMemory", "DBInstanceIdentifier", var.rds_identifier]
          ]
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 18
        width  = 12
        height = 6
        properties = {
          title  = "API Gateway — Errores 5xx"
          region = var.aws_region
          view   = "timeSeries"
          period = 60
          stat   = "Sum"
          metrics = [
            ["AWS/ApiGateway", "5XXError", "ApiId", var.api_id, "Stage", "$default"]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 18
        width  = 12
        height = 6
        properties = {
          title  = "API Gateway — Latencia integración (ms)"
          region = var.aws_region
          view   = "timeSeries"
          period = 60
          metrics = [
            ["AWS/ApiGateway", "IntegrationLatency", "ApiId", var.api_id, "Stage", "$default", { stat = "p99", label = "p99" }],
            ["AWS/ApiGateway", "IntegrationLatency", "ApiId", var.api_id, "Stage", "$default", { stat = "p50", label = "p50" }]
          ]
        }
      }
    ]
  })
}
