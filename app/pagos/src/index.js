'use strict';

const { createApp } = require('./app');
const { config } = require('./config');
const { disconnect } = require('./db');
const logger = require('./lib/logger');

const app = createApp();

const server = app.listen(config.port, () => {
  logger.info({ port: config.port, env: config.nodeEnv }, 'svc-pagos escuchando');
});

/**
 * Apagado ordenado: deja de aceptar conexiones, cierra Prisma y sale.
 * Importante para DISPONIBILIDAD durante despliegues/rotacion de tareas ECS.
 */
let cerrando = false;
async function shutdown(signal) {
  if (cerrando) return;
  cerrando = true;
  logger.info({ signal }, 'Recibida senal de apagado, cerrando...');

  server.close(async () => {
    try {
      await disconnect();
    } catch (err) {
      logger.error({ err }, 'error al cerrar Prisma');
    }
    logger.info('Servidor cerrado. Adios.');
    process.exit(0);
  });

  // Si algo se cuelga, no quedarse colgado para siempre.
  setTimeout(() => process.exit(1), 10000).unref();
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

module.exports = { app, server };
