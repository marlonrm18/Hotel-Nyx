'use strict';

/**
 * Carga y validacion de configuracion del servicio.
 *
 * Toda la config sensible (credenciales de BD, access token de Mercado Pago,
 * webhook secret) NO vive aqui: solo se guarda el ARN/nombre de los secrets en
 * Secrets Manager. Los valores se resuelven en runtime (ver src/db). Esto evita
 * secretos hardcodeados o versionados.
 */

function loadConfig() {
  const config = {
    // PORT lo inyecta la task definition de ECS (3001 para pagos).
    port: parseInt(process.env.PORT, 10) || 3001,
    nodeEnv: process.env.NODE_ENV || 'development',

    // Region de AWS. En Fargate puede no venir seteada; el SDK tambien la
    // resuelve por su cadena de proveedores, pero la dejamos explicita.
    awsRegion: process.env.AWS_REGION || process.env.AWS_DEFAULT_REGION || 'us-east-1',

    // ARN (o nombre) del secret de RDS en Secrets Manager. Inyectado por ECS
    // como DB_SECRET_ARN desde aws_secretsmanager_secret.rds.
    dbSecretId: process.env.DB_SECRET_ARN || process.env.DB_SECRET_NAME || null,

    // Parametros de la conexion a Postgres no sensibles.
    dbSchema: process.env.DB_SCHEMA || 'public',
    dbSslMode: process.env.DB_SSL_MODE || 'require',

    // ─── Mercado Pago (SANDBOX) ───────────────────────────────────────────────
    // ARN/nombre del secret con { access_token (TEST), webhook_secret }.
    // El infra debe inyectarlo como MP_SECRET_ARN en la task de svc-pagos.
    mpSecretId: process.env.MP_SECRET_ARN || process.env.MP_SECRET_NAME || null,
    mpCurrency: process.env.MP_CURRENCY || 'ARS',
    // URL publica del webhook (la arma el infra: https://<api>/api/pagos/webhook).
    mpNotificationUrl: process.env.MP_NOTIFICATION_URL || null,

    // ─── SES / correo ─────────────────────────────────────────────────────────
    domainName: process.env.DOMAIN_NAME || null,
    // Remitente verificado en SES. El infra debe inyectar MAIL_FROM (o DOMAIN_NAME).
    mailFrom:
      process.env.MAIL_FROM ||
      (process.env.DOMAIN_NAME ? `Hotel Nyx <no-reply@${process.env.DOMAIN_NAME}>` : null),

    // Base URL del frontend para las back_urls de Mercado Pago (opcional).
    appBaseUrl:
      process.env.APP_BASE_URL ||
      (process.env.DOMAIN_NAME ? `https://${process.env.DOMAIN_NAME}` : null),
  };

  return config;
}

const config = loadConfig();

module.exports = { config, loadConfig };
