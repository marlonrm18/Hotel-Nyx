# Módulo KMS: centraliza las 5 customer-managed keys (CMK) del proyecto y sus
# aliases. Cada key se cifra con rotación anual habilitada.
#
# - rds / ecr / frontend: sin policy inline (usan la default key policy o, en el
#   caso de frontend, una aws_kms_key_policy gestionada en el módulo consumidor
#   para romper la dependencia circular con CloudFront).
# - ecs_logs / monitoring: requieren key policy que autorice explícitamente al
#   servicio (CloudWatch Logs / CloudWatch Alarms). La policy es autocontenida
#   (solo depende de región/cuenta/partición) y por eso vive aquí.

# ─── CMK: RDS PostgreSQL ─────────────────────────────────────────────────────

resource "aws_kms_key" "rds" {
  description             = "${var.project}-${var.environment}: cifrado RDS PostgreSQL"
  deletion_window_in_days = var.kms_deletion_window_days
  enable_key_rotation     = true

  tags = { Name = "${var.project}-${var.environment}-kms-rds" }
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${var.project}-${var.environment}-rds"
  target_key_id = aws_kms_key.rds.key_id
}

# ─── CMK: repositorios ECR ───────────────────────────────────────────────────

resource "aws_kms_key" "ecr" {
  description             = "${var.project}-${var.environment}: cifrado repositorios ECR"
  deletion_window_in_days = var.kms_deletion_window_days
  enable_key_rotation     = true

  tags = { Name = "${var.project}-${var.environment}-kms-ecr" }
}

resource "aws_kms_alias" "ecr" {
  name          = "alias/${var.project}-${var.environment}-ecr"
  target_key_id = aws_kms_key.ecr.key_id
}

# ─── CMK: logs ECS / API Gateway ─────────────────────────────────────────────
# CloudWatch Logs requiere que el key policy incluya explicitamente
# el servicio logs.<region>.amazonaws.com, de ahi el policy dedicado.

data "aws_iam_policy_document" "ecs_logs" {
  statement {
    sid     = "RootAccess"
    effect  = "Allow"
    actions = ["kms:*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:${var.partition}:iam::${var.account_id}:root"]
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
      values   = ["arn:${var.partition}:logs:${var.aws_region}:${var.account_id}:*"]
    }
  }
}

resource "aws_kms_key" "ecs_logs" {
  description             = "${var.project}-${var.environment}: cifrado logs ECS"
  policy                  = data.aws_iam_policy_document.ecs_logs.json
  deletion_window_in_days = var.kms_deletion_window_days
  enable_key_rotation     = true

  tags = { Name = "${var.project}-${var.environment}-kms-ecs-logs" }
}

resource "aws_kms_alias" "ecs_logs" {
  name          = "alias/${var.project}-${var.environment}-ecs-logs"
  target_key_id = aws_kms_key.ecs_logs.key_id
}

# ─── CMK: S3 frontend ────────────────────────────────────────────────────────
# La key policy (que autoriza a CloudFront OAC) se crea en el módulo frontend
# mediante aws_kms_key_policy, para romper la dependencia circular
# aws_kms_key → S3 → CloudFront → key policy.

resource "aws_kms_key" "frontend" {
  description             = "${var.project}-${var.environment} — S3 frontend bucket"
  deletion_window_in_days = var.kms_deletion_window_days
  enable_key_rotation     = true

  tags = { Name = "${var.project}-${var.environment}-frontend-kms" }
}

resource "aws_kms_alias" "frontend" {
  name          = "alias/${var.project}-${var.environment}-frontend"
  target_key_id = aws_kms_key.frontend.key_id
}

# ─── CMK: SNS / monitoring ───────────────────────────────────────────────────
# CloudWatch necesita kms:GenerateDataKey* sobre la key del topic para publicar.

data "aws_iam_policy_document" "monitoring" {
  statement {
    sid    = "EnableRootAccess"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:${var.partition}:iam::${var.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowCloudWatchAlarms"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com"]
    }
    actions   = ["kms:GenerateDataKey*", "kms:Decrypt"]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [var.account_id]
    }
  }
}

resource "aws_kms_key" "monitoring" {
  description             = "${var.project}-${var.environment} — SNS alerts + monitoring"
  deletion_window_in_days = var.kms_deletion_window_days
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.monitoring.json

  tags = { Name = "${var.project}-${var.environment}-monitoring-kms" }
}

resource "aws_kms_alias" "monitoring" {
  name          = "alias/${var.project}-${var.environment}-monitoring"
  target_key_id = aws_kms_key.monitoring.key_id
}
