variable "project" {
  description = "Nombre del proyecto, usado en tags y nombres de recursos"
  type        = string
}

variable "environment" {
  description = "Nombre del ambiente de despliegue"
  type        = string
}

variable "cognito_password_min_length" {
  description = "Longitud minima de la contrasena de usuarios Cognito"
  type        = number
}

variable "cognito_mfa_configuration" {
  description = "Configuracion de MFA: OFF | OPTIONAL | ON"
  type        = string
}

variable "cognito_advanced_security_mode" {
  description = "Modo de seguridad avanzada de Cognito: OFF | AUDIT | ENFORCED"
  type        = string
}

variable "cognito_callback_urls" {
  description = "URLs de callback OAuth2 permitidas en el app client"
  type        = list(string)
}

variable "cognito_logout_urls" {
  description = "URLs de logout permitidas en el app client"
  type        = list(string)
}
