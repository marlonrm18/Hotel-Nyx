'use strict';

const pino = require('pino');

/**
 * Logger estructurado compartido por todo el servicio.
 * Nunca loguear credenciales ni la connection string (seguridad).
 */
const logger = pino({
  level: process.env.LOG_LEVEL || 'info',
  base: { service: 'svc-reservas' },
});

module.exports = logger;
