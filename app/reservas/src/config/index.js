'use strict';

/**
 * Carga y validacion de configuracion del servicio.
 *
 * Toda la config sensible (credenciales de BD) NO vive aqui: solo se guarda
 * el ARN/nombre del secret en Secrets Manager. La password se resuelve en
 * runtime (ver src/db). Esto evita secretos hardcodeados o versionados.
 */

function loadConfig() {
  const config = {
    // PORT lo inyecta la task definition de ECS (3000 para reservas).
    port: parseInt(process.env.PORT, 10) || 3000,
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
  };

  return config;
}

const config = loadConfig();

module.exports = { config, loadConfig };
