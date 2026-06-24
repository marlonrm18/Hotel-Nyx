# ─── CloudWatch Log Group para acceso a la API ───────────────────────────────
# Reutiliza la CMK de ECS logs (su key policy ya incluye CloudWatch Logs).

resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.project}-${var.environment}"
  retention_in_days = var.ecs_log_retention_days
  kms_key_id        = var.ecs_logs_key_arn

  tags = { Name = "${var.project}-${var.environment}-apigw-logs" }
}

# ─── HTTP API (v2) Regional ───────────────────────────────────────────────────
# HTTP API es ~70% mas barato que REST API y tiene soporte nativo de JWT.

resource "aws_apigatewayv2_api" "main" {
  name          = "${var.project}-${var.environment}-api"
  protocol_type = "HTTP"
  description   = "Hotel Nyx — HTTP API Regional"

  cors_configuration {
    allow_headers  = ["content-type", "authorization", "x-amz-date", "x-api-key"]
    allow_methods  = ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]
    allow_origins  = var.api_cors_allow_origins
    expose_headers = ["x-request-id"]
    max_age        = 300
  }

  tags = { Name = "${var.project}-${var.environment}-api" }
}

# ─── JWT Authorizer (Cognito) ─────────────────────────────────────────────────
# Valida el Bearer token en Authorization contra el User Pool.

resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id           = aws_apigatewayv2_api.main.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "${var.project}-${var.environment}-cognito-jwt"

  jwt_configuration {
    audience = [var.cognito_client_id]
    issuer   = "https://cognito-idp.${var.aws_region}.amazonaws.com/${var.cognito_user_pool_id}"
  }
}

# ─── Integracion HTTP_PROXY → ALB ────────────────────────────────────────────
# Pasa la ruta completa y el host original al backend para que el ALB
# pueda aplicar sus listener rules de path-based routing.

resource "aws_apigatewayv2_integration" "alb" {
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "HTTP_PROXY"
  integration_uri    = "https://${var.alb_dns_name}"
  integration_method = "ANY"

  # 1.0 mantiene compatibilidad con el formato de eventos esperado por el ALB.
  payload_format_version = "1.0"

  request_parameters = {
    # Reenviar el Host original para que la app sepa el dominio publico.
    "overwrite:header.X-Forwarded-Host" = "$request.header.Host"
  }
}

# ─── Rutas ───────────────────────────────────────────────────────────────────
# Scope requerido por ruta; el ALB aplica path-based routing internamente.

resource "aws_apigatewayv2_route" "reservas" {
  api_id               = aws_apigatewayv2_api.main.id
  route_key            = "ANY /api/reservas/{proxy+}"
  target               = "integrations/${aws_apigatewayv2_integration.alb.id}"
  authorization_type   = "JWT"
  authorizer_id        = aws_apigatewayv2_authorizer.cognito.id
  authorization_scopes = ["hotel-api/guest:reserve"]
}

resource "aws_apigatewayv2_route" "pagos" {
  api_id               = aws_apigatewayv2_api.main.id
  route_key            = "ANY /api/pagos/{proxy+}"
  target               = "integrations/${aws_apigatewayv2_integration.alb.id}"
  authorization_type   = "JWT"
  authorizer_id        = aws_apigatewayv2_authorizer.cognito.id
  authorization_scopes = ["hotel-api/guest:reserve"]
}

resource "aws_apigatewayv2_route" "admin" {
  api_id               = aws_apigatewayv2_api.main.id
  route_key            = "ANY /api/admin/{proxy+}"
  target               = "integrations/${aws_apigatewayv2_integration.alb.id}"
  authorization_type   = "JWT"
  authorizer_id        = aws_apigatewayv2_authorizer.cognito.id
  authorization_scopes = ["hotel-api/admin:write"]
}

# ─── Stage ───────────────────────────────────────────────────────────────────

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId        = "$context.requestId"
      ip               = "$context.identity.sourceIp"
      requestTime      = "$context.requestTime"
      httpMethod       = "$context.httpMethod"
      routeKey         = "$context.routeKey"
      status           = "$context.status"
      protocol         = "$context.protocol"
      responseLength   = "$context.responseLength"
      integrationError = "$context.integrationErrorMessage"
      authorizerError  = "$context.authorizer.error"
    })
  }

  default_route_settings {
    detailed_metrics_enabled = true
    throttling_burst_limit   = var.api_throttling_burst_limit
    throttling_rate_limit    = var.api_throttling_rate_limit
  }

  tags = { Name = "${var.project}-${var.environment}-api-stage" }
}

# ─── Dominio custom: api.hotelnyx.com ─────────────────────────────────────────
# Reutiliza el certificado wildcard *.hotelnyx.com ya validado en el módulo alb.

resource "aws_apigatewayv2_domain_name" "api" {
  domain_name = "api.${var.domain_name}"

  domain_name_configuration {
    certificate_arn = var.acm_certificate_arn
    endpoint_type   = "REGIONAL"
    security_policy = "TLS_1_2"
  }

  tags = { Name = "${var.project}-${var.environment}-api-domain" }
}

resource "aws_apigatewayv2_api_mapping" "api" {
  api_id      = aws_apigatewayv2_api.main.id
  domain_name = aws_apigatewayv2_domain_name.api.id
  stage       = aws_apigatewayv2_stage.default.id
}

# ─── Alias record: api.hotelnyx.com → API Gateway custom domain ───────────────
# Solo registro A: API Gateway Regional HTTP API no expone endpoint IPv6.

resource "aws_route53_record" "api_gateway" {
  zone_id = var.route53_zone_id
  name    = "api.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_apigatewayv2_domain_name.api.domain_name_configuration[0].target_domain_name
    zone_id                = aws_apigatewayv2_domain_name.api.domain_name_configuration[0].hosted_zone_id
    evaluate_target_health = false
  }
}
