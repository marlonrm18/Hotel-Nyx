'use strict';

const {
  SecretsManagerClient,
  GetSecretValueCommand,
} = require('@aws-sdk/client-secrets-manager');

const { config } = require('../config');

/**
 * Lee el secret de Mercado Pago desde AWS Secrets Manager en runtime, con la
 * MISMA convencion que la credencial de RDS (ver infra_runtime_contract).
 *
 * El secret es un JSON (modo SANDBOX / TEST):
 *   {
 *     "access_token":   "TEST-...",   // SECRETO. Solo lado servidor.
 *     "webhook_secret": "...",        // SECRETO. Valida la firma del webhook.
 *     "public_key":     "TEST-..."    // (opcional) parte PUBLICA, va al frontend.
 *   }
 *
 * El access_token y el webhook_secret NUNCA se hardcodean ni se loguean.
 * El infra (Terraform) debe crear este secret e inyectar su ARN como
 * MP_SECRET_ARN en la task definition de svc-pagos (paso de infra futuro).
 */

let cachedSecret = null;

async function getMpSecret() {
  if (cachedSecret) return cachedSecret;

  if (!config.mpSecretId) {
    throw new Error(
      'Falta MP_SECRET_ARN: no se puede resolver la credencial de Mercado Pago.'
    );
  }

  const client = new SecretsManagerClient({ region: config.awsRegion });
  const response = await client.send(
    new GetSecretValueCommand({ SecretId: config.mpSecretId })
  );

  if (!response.SecretString) {
    throw new Error('El secret de Mercado Pago no contiene SecretString.');
  }

  cachedSecret = JSON.parse(response.SecretString);
  return cachedSecret;
}

function clearMpSecretCache() {
  cachedSecret = null;
}

module.exports = { getMpSecret, clearMpSecretCache };
