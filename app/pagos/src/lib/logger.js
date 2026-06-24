'use strict';

const pino = require('pino');

/**
 * Logger estructurado compartido por todo el servicio.
 * Nunca loguear el access token de Mercado Pago, el webhook secret ni la
 * connection string (seguridad).
 */
const logger = pino({
  level: process.env.LOG_LEVEL || 'info',
  base: { service: 'svc-pagos' },
});

module.exports = logger;
