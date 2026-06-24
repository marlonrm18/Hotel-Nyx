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
# Se cifra con la MISMA CMK que el secret de RDS (aws_kms_key.rds), por
# consistencia. El task role de pagos tiene kms:Decrypt restringido a esa clave
# (ver iam.tf), via la condicion kms:ViaService = secretsmanager.

resource "aws_secretsmanager_secret" "mercadopago" {
  name                    = "${var.project}/${var.environment}/mercadopago"
  kms_key_id              = aws_kms_key.rds.arn
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
