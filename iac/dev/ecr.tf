# ─── KMS: cifrado de repositorios ECR ────────────────────────────────────────

resource "aws_kms_key" "ecr" {
  description             = "${var.project}-${var.environment}: cifrado repositorios ECR"
  deletion_window_in_days = var.kms_deletion_window_days
  enable_key_rotation     = true

  tags = {
    Name = "${var.project}-${var.environment}-kms-ecr"
  }
}

resource "aws_kms_alias" "ecr" {
  name          = "alias/${var.project}-${var.environment}-ecr"
  target_key_id = aws_kms_key.ecr.key_id
}

# ─── Lifecycle policy compartida (local para no duplicar JSON) ────────────────

locals {
  ecr_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Purgar imagenes sin tag tras 1 dia"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Retener las ultimas ${var.ecr_image_retention_count} imagenes"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.ecr_image_retention_count
        }
        action = { type = "expire" }
      }
    ]
  })
}

# ─── Repositorio: svc-reservas ────────────────────────────────────────────────

resource "aws_ecr_repository" "svc_reservas" {
  name                 = "${var.project}/${var.environment}/svc-reservas"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.ecr.arn
  }

  tags = {
    Name    = "${var.project}-${var.environment}-ecr-svc-reservas"
    Service = "svc-reservas"
  }
}

resource "aws_ecr_lifecycle_policy" "svc_reservas" {
  repository = aws_ecr_repository.svc_reservas.name
  policy     = local.ecr_lifecycle_policy
}

# ─── Repositorio: svc-pagos ───────────────────────────────────────────────────

resource "aws_ecr_repository" "svc_pagos" {
  name                 = "${var.project}/${var.environment}/svc-pagos"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.ecr.arn
  }

  tags = {
    Name    = "${var.project}-${var.environment}-ecr-svc-pagos"
    Service = "svc-pagos"
  }
}

resource "aws_ecr_lifecycle_policy" "svc_pagos" {
  repository = aws_ecr_repository.svc_pagos.name
  policy     = local.ecr_lifecycle_policy
}
