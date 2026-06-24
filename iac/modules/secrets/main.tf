# ─── Secret: credenciales RDS ────────────────────────────────────────────────
# El contenedor y la version los gestiona Terraform. La app los lee en runtime
# vía GetSecretValue con el ARN (ver módulos ecs/iam). Cifrado con la CMK de RDS.

resource "aws_secretsmanager_secret" "rds" {
  name                    = "${var.project}/${var.environment}/rds/credentials"
  kms_key_id              = var.rds_kms_key_arn
  recovery_window_in_days = var.secrets_recovery_window_days

  tags = { Name = "${var.project}-${var.environment}-secret-rds" }
}

resource "aws_secretsmanager_secret_version" "rds" {
  secret_id = aws_secretsmanager_secret.rds.id

  secret_string = jsonencode({
    engine   = "postgres"
    host     = var.db_host
    port     = var.db_port
    dbname   = var.db_name
    username = var.db_username
    password = var.db_password
  })
}

# ─── Mercado Pago: secret "cajón vacío" ───────────────────────────────────────
# Terraform crea el CONTENEDOR del secret y una version con valor PLACEHOLDER.
# El valor real (access_token TEST + webhook_secret) se inyecta DESPUES por CLI:
#
#   aws secretsmanager put-secret-value \
#     --secret-id hotel-nyx/dev/mercadopago \
#     --secret-string '{"access_token":"TEST-...","webhook_secret":"..."}'
#
# lifecycle.ignore_changes = [secret_string] evita que un futuro `apply` pise ese
# valor real con el placeholder. El secreto NUNCA se versiona en el codigo.
#
# Se cifra con la MISMA CMK que el secret de RDS, por consistencia. El task role
# de pagos tiene kms:Decrypt restringido a esa clave (ver módulo iam), via la
# condicion kms:ViaService = secretsmanager.

resource "aws_secretsmanager_secret" "mercadopago" {
  name                    = "${var.project}/${var.environment}/mercadopago"
  kms_key_id              = var.rds_kms_key_arn
  recovery_window_in_days = var.secrets_recovery_window_days

  tags = { Name = "${var.project}-${var.environment}-secret-mercadopago" }
}

resource "aws_secretsmanager_secret_version" "mercadopago" {
  secret_id = aws_secretsmanager_secret.mercadopago.id

  secret_string = jsonencode({
    access_token   = "REEMPLAZAR"
    webhook_secret = "REEMPLAZAR"
  })

  # El valor real lo carga el operador por CLI; Terraform no lo gestiona.
  lifecycle {
    ignore_changes = [secret_string]
  }
}
