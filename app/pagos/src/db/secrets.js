'use strict';

const {
  SecretsManagerClient,
  GetSecretValueCommand,
} = require('@aws-sdk/client-secrets-manager');

const { config } = require('../config');

/**
 * Lee el secret de credenciales de RDS desde AWS Secrets Manager en runtime.
 *
 * El secret es un JSON gestionado por Terraform con la forma:
 *   { engine, host, port, dbname, username, password }
 *
 * Nunca se loguea ni se persiste la password. Se cachea el resultado para no
 * golpear Secrets Manager en cada request.
 */

let cachedSecret = null;

async function getDbSecret() {
  if (cachedSecret) return cachedSecret;

  if (!config.dbSecretId) {
    throw new Error(
      'Falta DB_SECRET_ARN: no se puede resolver la credencial de la base de datos.'
    );
  }

  const client = new SecretsManagerClient({ region: config.awsRegion });
  const response = await client.send(
    new GetSecretValueCommand({ SecretId: config.dbSecretId })
  );

  if (!response.SecretString) {
    throw new Error('El secret de RDS no contiene SecretString.');
  }

  const parsed = JSON.parse(response.SecretString);
  cachedSecret = parsed;
  return parsed;
}

function clearSecretCache() {
  cachedSecret = null;
}

module.exports = { getDbSecret, clearSecretCache };
