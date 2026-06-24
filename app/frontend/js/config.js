'use strict';

/**
 * Configuracion PUBLICA del frontend de Hotel Nyx.
 *
 * ⚠️ SEGURIDAD: aqui SOLO van valores publicos. NUNCA pongas access tokens,
 * client secrets, la password de la BD ni la PRIVATE/ACCESS KEY de Mercado Pago.
 * Todos esos secretos viven en AWS Secrets Manager y los usa el backend.
 *
 * Reemplaza los placesholders REEMPLAZAR_* con los valores reales (salen de los
 * outputs de Terraform en iac/dev/):
 *   - API_BASE_URL          → output `api_custom_domain_url` (o `api_gateway_endpoint`)
 *   - COGNITO_HOSTED_UI     → output `cognito_hosted_ui_url`
 *   - COGNITO_USER_POOL_ID  → output `cognito_user_pool_id`
 *   - COGNITO_CLIENT_ID     → output `cognito_client_id`
 *   - MP_PUBLIC_KEY         → Public Key de TEST de Mercado Pago (es publica)
 *
 * REDIRECT_URI y LOGOUT_URI deben estar dados de alta en el app client de
 * Cognito (variables cognito_callback_urls / cognito_logout_urls del IaC).
 */
window.HOTEL_NYX_CONFIG = {
  // URL base del API Gateway (sin slash final). Ej: https://api.hotelnyx.com
  API_BASE_URL: 'https://REEMPLAZAR_API_GATEWAY',

  // Hosted UI de Cognito. Ej: https://hotel-nyx-dev.auth.us-east-2.amazoncognito.com
  COGNITO_HOSTED_UI: 'https://REEMPLAZAR_COGNITO_HOSTED_UI',
  COGNITO_USER_POOL_ID: 'REEMPLAZAR_USER_POOL_ID',
  COGNITO_CLIENT_ID: 'REEMPLAZAR_CLIENT_ID',

  // Scopes solicitados al iniciar sesion (incluye los custom del resource server).
  COGNITO_SCOPES: 'openid email profile hotel-api/guest:reserve hotel-api/admin:write',

  // Deben coincidir EXACTAMENTE con las URLs registradas en el app client.
  // Por defecto se calculan a partir del origen actual (CloudFront).
  REDIRECT_URI: window.location.origin + '/login.html',
  LOGOUT_URI: window.location.origin + '/index.html',

  // Public Key de TEST de Mercado Pago (publica, se usa para el checkout).
  MP_PUBLIC_KEY: 'TEST-REEMPLAZAR_MP_PUBLIC_KEY',

  // Scope que habilita el panel de administracion.
  ADMIN_SCOPE: 'hotel-api/admin:write',
};
