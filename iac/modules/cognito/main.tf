# ─── User Pool ───────────────────────────────────────────────────────────────

resource "aws_cognito_user_pool" "main" {
  name = "${var.project}-${var.environment}-user-pool"

  # Contraseña fuerte por defecto; los usuarios pueden cambiarse a si mismos.
  password_policy {
    minimum_length                   = var.cognito_password_min_length
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = true
    require_uppercase                = true
    temporary_password_validity_days = 7
  }

  mfa_configuration = var.cognito_mfa_configuration

  # Verificacion y recuperacion solo por email (sin SMS = sin costo Cognito SMS).
  auto_verified_attributes = ["email"]

  username_attributes = ["email"]
  username_configuration {
    case_sensitive = false
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  # Email de verificacion por defecto (SES personalizado se configura fuera de TF
  # o bien con aws_cognito_user_pool_email_config una vez verificado el dominio SES).
  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
    email_subject        = "Hotel Nyx: codigo de verificacion"
    email_message        = "Tu codigo de verificacion es {####}"
  }

  user_pool_add_ons {
    advanced_security_mode = var.cognito_advanced_security_mode
  }

  # Evitar que Cognito devuelva info sobre si el usuario existe (previene user enumeration).
  deletion_protection = "INACTIVE"

  tags = { Name = "${var.project}-${var.environment}-user-pool" }
}

# ─── Dominio Cognito (hosted UI) ──────────────────────────────────────────────

resource "aws_cognito_user_pool_domain" "main" {
  domain       = "${var.project}-${var.environment}"
  user_pool_id = aws_cognito_user_pool.main.id
}

# ─── Resource Server + Scopes ─────────────────────────────────────────────────

resource "aws_cognito_resource_server" "main" {
  name         = "hotel-api"
  identifier   = "hotel-api"
  user_pool_id = aws_cognito_user_pool.main.id

  scope {
    scope_name        = "guest:reserve"
    scope_description = "Crear y consultar reservas como huesped"
  }

  scope {
    scope_name        = "admin:write"
    scope_description = "Operaciones de escritura administrativas"
  }
}

# ─── App Client ───────────────────────────────────────────────────────────────
# Authorization Code + PKCE: flujo recomendado para SPAs y apps moviles.

resource "aws_cognito_user_pool_client" "main" {
  name         = "${var.project}-${var.environment}-client"
  user_pool_id = aws_cognito_user_pool.main.id

  # Sin client secret → cliente publico (SPA/mobile). Para microservicios
  # server-side se crearia un segundo cliente con generate_secret = true.
  generate_secret = false

  allowed_oauth_flows                  = ["code"]
  allowed_oauth_flows_user_pool_client = true

  allowed_oauth_scopes = concat(
    ["openid", "email", "profile"],
    aws_cognito_resource_server.main.scope_identifiers,
  )

  callback_urls = var.cognito_callback_urls
  logout_urls   = var.cognito_logout_urls

  supported_identity_providers = ["COGNITO"]

  # Previene que los mensajes de error revelen si el usuario existe.
  prevent_user_existence_errors = "ENABLED"

  enable_token_revocation = true

  # Validez de tokens
  access_token_validity  = 1
  id_token_validity      = 1
  refresh_token_validity = 30

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }

  # No permitir flujos legacy (implicit / password) para reducir superficie de ataque.
  explicit_auth_flows = [
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH",
  ]

  read_attributes = [
    "email",
    "email_verified",
    "name",
    "given_name",
    "family_name",
    "custom:role",
  ]

  write_attributes = [
    "email",
    "name",
    "given_name",
    "family_name",
  ]
}

# ─── Grupos de usuarios ───────────────────────────────────────────────────────

resource "aws_cognito_user_group" "admin" {
  name         = "admin"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "Administradores del sistema Hotel Nyx"
  precedence   = 1
}

resource "aws_cognito_user_group" "guest" {
  name         = "guest"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "Huespedes registrados"
  precedence   = 2
}
