# ─────────────────────────────────────────────────────────────────────────────
# Recursos del backend remoto de Terraform:
#   • Bucket S3 que guarda el state (cifrado, versionado, sin acceso público).
#   • Tabla DynamoDB que provee el state locking (evita applies concurrentes).
# ─────────────────────────────────────────────────────────────────────────────

locals {
  state_bucket_name = "${var.project}-tfstate-${var.name_suffix}"
}

# ─── Bucket S3 del state ──────────────────────────────────────────────────────
resource "aws_s3_bucket" "state" {
  bucket        = local.state_bucket_name
  force_destroy = var.force_destroy_state_bucket

  # SEGURIDAD/DISPONIBILIDAD: el state es crítico; evitamos un destroy accidental.
  lifecycle {
    prevent_destroy = true
  }

  tags = { Name = local.state_bucket_name }
}

# Versionado: permite recuperar revisiones anteriores del state si se corrompe.
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Cifrado en reposo (SSE-S3 / AES256). El bootstrap no gestiona una CMK propia
# para no introducir dependencias; AES256 ya cubre el cifrado en reposo del state.
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Bloqueo TOTAL de acceso público (los 4 flags en true).
resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Política: denegar cualquier acceso que no use TLS (defensa en profundidad).
resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource = [
        aws_s3_bucket.state.arn,
        "${aws_s3_bucket.state.arn}/*"
      ]
      Condition = {
        Bool = { "aws:SecureTransport" = "false" }
      }
    }]
  })

  # El public access block debe aplicarse antes que la policy.
  depends_on = [aws_s3_bucket_public_access_block.state]
}

# ─── Tabla DynamoDB para el state locking ─────────────────────────────────────
resource "aws_dynamodb_table" "locks" {
  name         = var.lock_table_name
  billing_mode = "PAY_PER_REQUEST" # on-demand: sin capacidad provisionada
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }

  tags = { Name = var.lock_table_name }
}
