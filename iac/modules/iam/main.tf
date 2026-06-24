# Assume-role policy reutilizable para tareas ECS.
# La condicion aws:SourceArn previene el confused-deputy attack.
data "aws_iam_policy_document" "ecs_task_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:${var.partition}:ecs:${var.aws_region}:${var.account_id}:*"]
    }
  }
}

# ─── Task Execution Role (compartido) ────────────────────────────────────────
# Permite a Fargate descargar imagenes de ECR, escribir logs y leer secretos
# de Secrets Manager antes de que el contenedor arranque.

resource "aws_iam_role" "ecs_task_execution" {
  name               = "${var.project}-${var.environment}-ecs-execution-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json

  tags = { Name = "${var.project}-${var.environment}-ecs-execution-role" }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_managed" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:${var.partition}:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "ecs_task_execution_extra" {
  statement {
    sid     = "SecretsManagerRead"
    effect  = "Allow"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      "arn:${var.partition}:secretsmanager:${var.aws_region}:${var.account_id}:secret:${var.project}/*",
    ]
  }

  # Descifrar secretos que usan KMS customer-managed keys del proyecto.
  statement {
    sid     = "KMSDecrypt"
    effect  = "Allow"
    actions = ["kms:Decrypt", "kms:DescribeKey"]
    resources = [
      "arn:${var.partition}:kms:${var.aws_region}:${var.account_id}:*",
    ]
    condition {
      test     = "StringLike"
      variable = "kms:ViaService"
      values   = ["secretsmanager.${var.aws_region}.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "ecs_task_execution_extra" {
  name   = "secrets-kms"
  role   = aws_iam_role.ecs_task_execution.id
  policy = data.aws_iam_policy_document.ecs_task_execution_extra.json
}

# ─── Task Role: svc-reservas ──────────────────────────────────────────────────
# Permisos del proceso en tiempo de ejecucion. Separado del execution role.

resource "aws_iam_role" "svc_reservas_task" {
  name               = "${var.project}-${var.environment}-svc-reservas-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json

  tags = {
    Name    = "${var.project}-${var.environment}-svc-reservas-task"
    Service = "svc-reservas"
  }
}

data "aws_iam_policy_document" "svc_reservas_task" {
  # SES: restringido al identity del dominio y al From del propio dominio.
  statement {
    sid     = "SESSendEmail"
    effect  = "Allow"
    actions = ["ses:SendEmail", "ses:SendRawEmail"]
    resources = [
      "arn:${var.partition}:ses:${var.aws_region}:${var.account_id}:identity/${var.domain_name}",
    ]
    condition {
      test     = "StringLike"
      variable = "ses:FromAddress"
      values   = ["*@${var.domain_name}"]
    }
  }

  statement {
    sid     = "SecretsManagerRead"
    effect  = "Allow"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      # Secret de RDS por ARN exacto: la app lo lee en runtime con este task role.
      var.rds_secret_arn,
      # Secrets propios del servicio (futuros), bajo su prefijo.
      "arn:${var.partition}:secretsmanager:${var.aws_region}:${var.account_id}:secret:${var.project}/${var.environment}/reservas/*",
    ]
  }

  # Descifrar el secret de RDS (cifrado con la CMK del RDS) al leerlo en runtime.
  statement {
    sid       = "KMSDecryptSecrets"
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:DescribeKey"]
    resources = [var.rds_kms_key_arn]
    condition {
      test     = "StringLike"
      variable = "kms:ViaService"
      values   = ["secretsmanager.${var.aws_region}.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "svc_reservas_task" {
  name   = "ses-secrets"
  role   = aws_iam_role.svc_reservas_task.id
  policy = data.aws_iam_policy_document.svc_reservas_task.json
}

# ─── Task Role: svc-pagos ─────────────────────────────────────────────────────

resource "aws_iam_role" "svc_pagos_task" {
  name               = "${var.project}-${var.environment}-svc-pagos-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json

  tags = {
    Name    = "${var.project}-${var.environment}-svc-pagos-task"
    Service = "svc-pagos"
  }
}

data "aws_iam_policy_document" "svc_pagos_task" {
  statement {
    sid     = "SecretsManagerRead"
    effect  = "Allow"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      # Secret de RDS por ARN exacto: la app lo lee en runtime con este task role.
      var.rds_secret_arn,
      # Secrets propios del servicio (futuros), bajo su prefijo.
      "arn:${var.partition}:secretsmanager:${var.aws_region}:${var.account_id}:secret:${var.project}/${var.environment}/pagos/*",
    ]
  }

  # Mercado Pago: acceso SOLO a este secret (por ARN exacto), no por wildcard.
  statement {
    sid     = "MercadoPagoSecretRead"
    effect  = "Allow"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      var.mercadopago_secret_arn,
    ]
  }

  # Descifrar los secrets de RDS y de Mercado Pago: ambos cifrados con la CMK del
  # RDS. Restringido a esa clave y al uso via Secrets Manager.
  statement {
    sid       = "KMSDecryptSecrets"
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:DescribeKey"]
    resources = [var.rds_kms_key_arn]
    condition {
      test     = "StringLike"
      variable = "kms:ViaService"
      values   = ["secretsmanager.${var.aws_region}.amazonaws.com"]
    }
  }

  # SES: svc-pagos envia el correo de confirmacion (email.service.js). Restringido
  # al identity del dominio y al From del propio dominio, igual que svc-reservas.
  statement {
    sid     = "SESSendEmail"
    effect  = "Allow"
    actions = ["ses:SendEmail", "ses:SendRawEmail"]
    resources = [
      "arn:${var.partition}:ses:${var.aws_region}:${var.account_id}:identity/${var.domain_name}",
    ]
    condition {
      test     = "StringLike"
      variable = "ses:FromAddress"
      values   = ["*@${var.domain_name}"]
    }
  }
}

resource "aws_iam_role_policy" "svc_pagos_task" {
  name   = "secrets-ses"
  role   = aws_iam_role.svc_pagos_task.id
  policy = data.aws_iam_policy_document.svc_pagos_task.json
}
